# Inventário inicial da revisão visual

O branch iniciou limpo no commit `1f640c9`. Havia 13 cenas, três Autoloads, motores puros para os três jogos, controlador autoritativo, protocolo ENet e runners sem addons. Os baralhos, regras e snapshots já estavam implementados, mas as três mesas repetiam a mesma árvore genérica, `GameUI` mostrava o snapshot com `str()`, e `CardVisual` era um botão textual. Menu não possuía ajuda, resultados exibiam o dicionário inteiro e não havia tema compartilhado.

Foram preservadas as correções anteriores de `match`, tipagem dinâmica, normalização de `Array[Dictionary]` por RPC e conversão de `SpinBox`. A Godot não está instalada neste contêiner; portanto este inventário e a revisão são estáticos até a validação descrita em `LOCAL_VALIDATION.md`.
