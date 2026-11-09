# ABT 0.9.2 shared bridge runtime. No Python imports happen at file load.
struct ABTPythonNamespace
    modules::Dict{String,Any}
    prefix::String
end

function abt_load_julia_package(name::String, uuid::String, version::String)
    mod = try
        Base.require(Base.PkgId(Base.UUID(uuid), name))
    catch err
        error("ABT package '$name' unavailable: " * sprint(showerror, err))
    end
    got = Base.pkgversion(mod)
    string(got) == version || error("ABT package '$name' version mismatch: expected $version, got $got")
    return mod
end
ABTPythonNamespace() = ABTPythonNamespace(Dict{String,Any}(), "")

function abt_import_python!(ns::ABTPythonNamespace, path::String, pyimport)
    # Validate before invoking user-controlled module initialization.
    occursin(r"^[A-Za-z][A-Za-z_0-9]*(\.[A-Za-z][A-Za-z_0-9]*)*$", path) ||
        error("ABT interop: caminho de módulo inválido: $path")
    any(startswith(part, "_") for part in split(path, '.')) &&
        error("ABT interop: componente privado: $path")
    module_object = Base.invokelatest(pyimport, path)  # Import first: failure cannot publish a partial namespace.
    ns.modules[path] = module_object
    return nothing
end

function abt_external_field(obj, field::String)
    startswith(field, "_") && error("ABT interop: atributo privado não permitido: $field")
    if obj isa ABTPythonNamespace
        path = isempty(obj.prefix) ? field : obj.prefix * "." * field
        # Imported modules are objects; unimported parents are namespace views.
        if any(startswith(k, path * ".") for k in keys(obj.modules))
            return ABTPythonNamespace(obj.modules, path)
        elseif haskey(obj.modules, path)
            return obj.modules[path]
        elseif haskey(obj.modules, obj.prefix)
            return abt_external_field(obj.modules[obj.prefix], field)
        end
        error("ABT interop: módulo ou atributo não importado: $path")
    end
    pymod = parentmodule(typeof(obj))
    if nameof(pymod) == :PythonCall && isdefined(pymod, :Py) && obj isa getfield(pymod, :Py)
        return Base.invokelatest(getfield(pymod, :pygetattr), obj, field)
    end
    return obj isa AbstractDict ? obj[field] : getproperty(obj, Symbol(field))
end

function abt_invoke(fn, args...)
    if isdefined(@__MODULE__, :PythonCall) && fn isa PythonCall.Py
        # Preserve the original PythonCall exception and its traceback.
        # Wrapping it in ErrorException would destroy structured error identity.
        return Base.invokelatest(fn, args...)
    end
    return Base.invokelatest(fn, args...)
end

# PythonCall uses process-wide Python state (sys.modules). This cache only holds
# the Julia package module; it is not an interpreter or security sandbox.
function abt_load_pythoncall!(cache::Base.RefValue)
    cache[] !== nothing && return cache[]
    deps = Module(gensym(:ABTPythonDeps))
    try
        Core.eval(deps, :(import PythonCall))
    catch err
        error("Interop Python indisponível: verifique PythonCall.jl. Causa: " * sprint(showerror, err))
    end
    cache[] = Base.invokelatest(getfield, deps, :PythonCall)
    return cache[]
end
