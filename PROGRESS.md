# Progresso

- **Última fase implementada:** Fase 17 — Polimento, exportação e documentação.
- **Fase atual:** **CORREÇÃO IMPLEMENTADA — VALIDAÇÃO LOCAL PENDENTE**.
- **Arquivos implementados:** configuração Godot/exportação; três Autoloads; dados, protocolo e construtor de baralhos; regras/controladores/UI de Uno, Caxeta e Truco; 13 cenas e 40 scripts GDScript; testes puros, de cena e rede; documentação/checkpoints.
- **Verificações realizadas:** inventário integral de `.gd`, `.tscn`, testes e `project.godot`; auditorias de inferência `:=`, `match`, `Dictionary.get()`, `back()`/`pop_*()`, valores de `SpinBox`, caminhos `res://`, recursos externos e propriedades duplicadas de cenas. Foram corrigidos o `match` inválido de início da partida, inferências sobre `Variant`, conversões de valores dinâmicos e a propriedade `text` duplicada de `Address`.
- **Validações locais pendentes:** todos os itens numerados em `LOCAL_VALIDATION.md`, especialmente parser/importação Godot 4.5.1, testes headless, interação, export Windows e LAN em dois PCs.
- **Próximo trabalho exato:** executar, com Godot 4.5.1 stable, `godot --version`, `godot --headless --path . --import`, `godot --headless --path . --script res://tests/test_runner.gd` e `godot --headless --path . --script res://tests/scene_smoke_runner.gd`; depois executar os smoke tests servidor/cliente dos itens 6–7 de `LOCAL_VALIDATION.md`.

## Revisão visual e de segurança atual

- Substituída a saída crua de snapshots por mesas específicas e textos em português.
- Implementados tema central, cartas procedurais com frente/verso/estados, adversários, pilhas, mesa, mão rolável e ações contextuais.
- Adicionadas ajuda com abas, resultados amigáveis, inventário inicial e matriz de testes.
- O controlador agora aplica ações em cópia profunda e só promove estado aceito, válido e com incremento unitário de versão.
- **Limitação real:** a Godot 4.5.1 e templates não existem neste ambiente; parser, runners, renderização, multiplayer físico e exportação continuam pendentes e não são declarados aprovados.
