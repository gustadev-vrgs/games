# Progresso

## Modo Treino local (2026-08-26)

- Configuração local de Uno (2–8), Caxeta (2–5, 7/10 vidas) e Truco (1x1/2x2), sem ENet.
- Reutilização de `BaseMatchController`, regras e snapshots; mãos virtuais ficam em cache privado exclusivo do treino e o controle segue o estado autoritativo.
- Saída e revanche limpam controlador, timers, ações, snapshots e estado. Testes headless e percurso manual permanecem pendentes porque a Godot não está instalada neste ambiente.

## Correção prioritária — mesa responsiva e Truco espanhol

- Protocolo 3 e baralho espanhol autoritativo de 40 cartas, sem ranks franceses no Truco.
- Cartas encobertas validadas pelo host a partir do segundo turno e sanitizadas nos snapshots públicos.
- Mesa dividida em cabeçalho fixo, conteúdo flexível, mão horizontal e ações permanentes; vira/monte à esquerda e histórico visual à direita.
- Declaração de UNO antes da penúltima carta, confirmação de penalidade e saída permanente para o menu.
- Validação LAN manual de duas instâncias permanece pendente no ambiente sem executável Godot.
- Catálogo completo com 40 frentes SVG espanholas distintas, um verso SVG, carregador `Texture2D` e galeria de desenvolvimento.
- Formatação centralizada cobre Truco, Uno, Caxeta e singular/plural de cartas e jogadores.
- Saída centralizada e idempotente conclui cliente e host no menu, com janela limitada para RPC confiável, fallback offline e repetição segura da transição de cena.

- **Última fase implementada:** Fase 17 — Polimento, exportação e documentação.
- **Fase atual:** **FLUXO DE CARTAS E REENTRÂNCIA CORRIGIDOS — VALIDAÇÃO GODOT/LAN PENDENTE**.
- **Arquivos implementados:** configuração Godot/exportação; três Autoloads; dados, protocolo e construtor de baralhos; regras/controladores/UI de Uno, Caxeta e Truco; 13 cenas e 40 scripts GDScript; testes puros, de cena e rede; documentação/checkpoints.
- **Verificações realizadas:** inventário integral de `.gd`, `.tscn`, testes e `project.godot`; auditorias de inferência `:=`, `match`, `Dictionary.get()`, `back()`/`pop_*()`, valores de `SpinBox`, caminhos `res://`, recursos externos e propriedades duplicadas de cenas. Foram corrigidos o `match` inválido de início da partida, inferências sobre `Variant`, conversões de valores dinâmicos e a propriedade `text` duplicada de `Address`.
- **Validações locais pendentes:** todos os itens numerados em `LOCAL_VALIDATION.md`, especialmente parser/importação Godot 4.5.1, testes headless, interação, export Windows e LAN em dois PCs.
- **Próximo trabalho exato:** executar, com Godot 4.5.1 stable, `godot --version`, `godot --headless --path . --import`, `godot --headless --path . --script res://tests/test_runner.gd` e `godot --headless --path . --script res://tests/scene_smoke_runner.gd`; depois executar os smoke tests servidor/cliente dos itens 6–7 de `LOCAL_VALIDATION.md`.

## Checkpoint — interação e confirmação de cartas

- O envio local do host agora é diferido, eliminando a resposta reentrante antes do registro de `pending_action`; IDs antigos são ignorados e a guarda pendente impede duplo envio.
- A espera possui timeout de oito segundos e também é cancelada em aceite, rejeição ou interrupção de sessão, sempre recalculando os controles sem reenvio automático.
- Seleção e legalidade foram separadas em `interactable`, `playable_hint`, `selected`, `pending` e `face_up`; o desenho interno/tween não move o `Control` administrado pelo `HBoxContainer`.
- Uno, Caxeta e Truco agora calculam ações por turno e fase. Uno valida compatibilidade e carta recém-comprada e usa modal de cor; Caxeta exige compra; Truco bloqueia durante resposta e respeita equipe/limite do aumento.
- A seleção é preservada quando UID, turno e fase continuam compatíveis, e limpa ao remover a carta, trocar turno/fase, aceitar ação, pressionar `Esc` ou selecionar a mesma carta.
- `tests/test_action_flow.gd` cobre políticas dos três jogos, preservação/limpeza e guardas estruturais de confirmação, timeout, duplicidade e resposta obsoleta. Parser, renderização responsiva e smoke LAN de duas instâncias continuam dependentes de Godot 4.5.1 instalado.

## Revisão visual e de segurança atual

- Substituída a saída crua de snapshots por mesas específicas e textos em português.
- Implementados tema central, cartas procedurais com frente/verso/estados, adversários, pilhas, mesa, mão rolável e ações contextuais.
- Adicionadas ajuda com abas, resultados amigáveis, inventário inicial e matriz de testes.
- O controlador agora aplica ações em cópia profunda e só promove estado aceito, válido e com incremento unitário de versão.
- **Limitação real:** a Godot 4.5.1 e templates não existem neste ambiente; parser, runners, renderização, multiplayer físico e exportação continuam pendentes e não são declarados aprovados.

## Checkpoint — jogabilidade multiplayer das mesas

- Saída confirmada e idempotente implementada em lobby, mesas e resultados, incluindo encerramento pelo host e cancelamento da partida por saída de cliente.
- Uno possui monte central clicável, reciclagem conservativa, feedback contextual, escolha modal de cor e evento público `last_play`.
- Truco possui progressão completa dos pedidos, modal contextual, histórico público e revelação autoritativa temporizada com token de versão.
- Testes determinísticos de regras foram ampliados para compra/reciclagem/curinga do Uno e pedidos/revelação/histórico do Truco.
- Godot 4.5.1 e validação LAN de duas instâncias permanecem pendentes neste ambiente quando o binário não estiver disponível.

## Complemento multiplayer — protocolo v3
- [x] Uno configurável de 2 a 8 (host + sete clientes ENet).
- [x] Truco 1v1 e 2v2 com equipes autoritativas e ordem A-B-A-B por assento.
- [x] Escolha/troca/saída de equipe, capacidade concorrente e pronto obrigatório.
- [x] Snapshots públicos de equipes sem mãos e snapshots privados por peer.
- [x] Lobby e adversários responsivos; no máximo cinco versos compactos.
- [x] Testes determinísticos de oito jogadores, conservação e privacidade.
- [ ] Validação LAN física com oito computadores (não disponível no ambiente automatizado).
