// Tokenize only displayed ABT examples. Program semantics remain in Julia.
document.addEventListener("DOMContentLoaded", () => {
  const token = /#[^\n]*|"(?:\\.|[^"\\])*"|\b(?:mostrar|show|se|if|senao|senão|else|para|for|cada|each|em|in|função|funcao|function|retornar|return|usar|verdadeiro|falso|true|false|e|and|ou|or|onde|where|de|of|soma|sum|media|média|average|filtrar|transformar|limitar|valor)\b|\b\d+(?:\.\d+)?\b/g;
  for (const code of document.querySelectorAll("pre code.language-abt")) {
    const source = code.textContent;
    const fragment = document.createDocumentFragment();
    let previous = 0;
    for (const match of source.matchAll(token)) {
      fragment.append(document.createTextNode(source.slice(previous, match.index)));
      const span = document.createElement("span");
      span.className = match[0].startsWith("#") ? "abt-comment" :
        match[0].startsWith('"') ? "abt-string" : /^\d/.test(match[0]) ? "abt-number" : "abt-keyword";
      span.textContent = match[0];
      fragment.append(span);
      previous = match.index + match[0].length;
    }
    fragment.append(document.createTextNode(source.slice(previous)));
    code.replaceChildren(fragment);
  }
});
