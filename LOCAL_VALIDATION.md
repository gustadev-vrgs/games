# Validação local obrigatória — Godot 4.5.1 stable

> **Status: CORREÇÃO IMPLEMENTADA — VALIDAÇÃO LOCAL PENDENTE.** O ambiente da correção não disponibilizou `godot` nem `godot4`; portanto, os comandos abaixo não foram declarados como aprovados e devem ser executados em uma instalação local da versão exata.

Na rodada LAN com duas instâncias, valide o Truco espanhol (vira e monte à esquerda, encoberta bloqueada no primeiro turno, verso privado no segundo/terceiro, histórico lateral e progressão Truco/6/9/12), a declaração de UNO com duas cartas e vitória ao zerar a mão, e a saída de cliente/host para o menu. Repita em 1280×720, 1366×768, 1600×900 e 1920×1080, confirmando cabeçalho, mão e barra de ações dentro do viewport.

1. Instale **Godot 4.5.1 stable** e os templates de exportação da mesma versão.
2. Na raiz do repositório, confirme: `godot --version` (deve reportar `4.5.1.stable`).
3. Importe recursos: `godot --headless --path . --import`.
4. Rode regras e baralhos: `godot --headless --path . --script res://tests/test_runner.gd`.
5. Rode cenas: `godot --headless --path . --script res://tests/scene_smoke_runner.gd`.
6. Rode o fluxo real de saída pelas mesas: `godot --headless --path . --script res://tests/leave_flow_runner.gd`.
7. Inicie o smoke servidor em um terminal: `godot --headless --path . --script res://tests/network_smoke_server.gd`.
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

## Roteiro final em dois computadores

1. Instale/copie exatamente a mesma build nos dois computadores e confirme que ambos estão na mesma LAN.
2. No Firewall do Windows, permita o executável e tráfego UDP na porta escolhida.
3. No PC host, crie a sala; confirme que ele aparece no assento 1 e continua como jogador.
4. No cliente, informe o IPv4 exibido e a porta; permaneça no lobby por 30 segundos e confira lista/assentos.
5. Inicie o jogo, execute turnos nos dois lados, conclua a partida e volte ao lobby pelo host.
6. Inicie uma segunda partida e confirme mãos, placar, vidas e versão reiniciados.
7. Desconecte um cliente no lobby; confirme remoção e reorganização. Repita durante partida; confirme pausa.
8. Desconecte o host; confirme nos clientes limpeza da mão, encerramento do peer e retorno seguro ao menu.
9. Repita os passos 3–8 para Uno, Caxeta e Truco 1x1.
10. Para Truco 2x2, use quatro instâncias/PCs, confirme equipes 0/2 e 1/3, parceiro oposto e ordem dos quatro assentos.

Se uma máquina usa `10.x.x.x` e a outra `172.16.x.x`–`172.31.x.x`, elas provavelmente estão em sub-redes/VLANs diferentes. Compare máscara e gateway, desative VPN, procure “isolamento de clientes/AP” no roteador e peça ao administrador uma VLAN comum ou roteamento/liberação UDP entre as redes. `127.0.0.1` nunca alcança outro computador.
