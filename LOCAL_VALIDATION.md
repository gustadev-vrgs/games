# Validação local obrigatória — Godot 4.5.1 stable

1. Instale **Godot 4.5.1 stable** e os templates de exportação da mesma versão.
2. Na raiz do repositório, confirme: `godot --version` (deve reportar `4.5.1.stable`).
3. Importe recursos: `godot --headless --path . --import`.
4. Rode regras e baralhos: `godot --headless --path . --script res://tests/test_runner.gd`.
5. Rode cenas: `godot --headless --path . --script res://tests/scene_smoke_runner.gd`.
6. Inicie o smoke servidor em um terminal: `godot --headless --path . --script res://tests/network_smoke_server.gd`.
7. Em até 12 segundos, inicie o cliente em outro terminal: `godot --headless --path . --script res://tests/network_smoke_client.gd`.
8. Abra `project.godot` no editor, execute o projeto e percorra Menu → Criar/Entrar → Lobby; clique repetidamente para confirmar que não há transição dupla.
9. Teste em 1280×720, 1600×900 e 1920×1080, incluindo redimensionamento, teclado e textos longos.
10. Em instâncias locais, conclua Uno (2 e 6 jogadores), Caxeta (2 e 5) e Truco (2 e 4); confirme turno, ações especiais, batidas, vidas, pedidos e placar.
11. Confirme no depurador de rede que snapshots públicos não contêm `hand`, `draw_pile`, seed ou mão adversária; snapshots privados devem usar `rpc_id` e ter o `peer_id` destinatário.
12. Teste pacote repetido, UID falso, ação fora do turno, estado antigo, protocolo incompatível, entrada tardia e timeout de cena.
13. Feche um cliente no lobby e durante cada jogo; a lista deve atualizar no lobby e a partida deve pausar. Feche o host; clientes devem limpar mãos e voltar ao menu.
14. Execute duas partidas seguidas na mesma sala e confirme ausência de estado residual.
15. Em dois PCs Windows 10/11 na mesma LAN, permita UDP no firewall, copie a mesma build, use o IPv4 LAN exibido pelo host (não `127.0.0.1`) e repita uma partida completa de cada jogo; use quatro instâncias/PCs para Truco 2x2.
16. Instale templates e exporte: `godot --headless --path . --export-release "Windows Desktop" build/HubDeCartas.exe`.
17. Abra `build/HubDeCartas.exe` nos dois PCs e repita conexão, desconexão, retorno ao lobby e encerramento.
