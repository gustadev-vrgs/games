# Hub de Cartas

Hub multiplayer LAN autoritativo em português para **Godot 4.5.1 stable**, com Uno clássico (108 cartas), Caxeta fechada (104 cartas) e Truco Paulista (40 cartas, 1x1/2x2).

## Abrir e executar

Instale Godot 4.5.1, abra `project.godot` e pressione F6/F5. Pela linha de comando: `godot --editor --path .` ou `godot --path .`. O host informa apelido, escolhe **Criar sala**, jogo, vidas da Caxeta e porta; clientes escolhem **Entrar**, informam o IPv4 LAN e a mesma porta. Uno aceita 2–6, Caxeta 2–5 e Truco exatamente 2 ou 4 jogadores.

## Rede e privacidade

O host é servidor e jogador (peer 1). ENet usa UDP, padrão 7000. O servidor valida envelopes, sessão, partida, versão, turno, propriedade do UID e regra; IDs de ação são deduplicados. Estado público contém apenas mesa e contagens; cada mão é enviada exclusivamente ao dono por `rpc_id`. A barreira `scene_ready` impede distribuição antes das cenas. Desconexão no jogo pausa; perda do host limpa dados secretos.

Use o endereço mostrado no lobby, normalmente `192.168.x.x` ou `10.x.x.x`. `127.0.0.1` funciona somente no mesmo computador. Todos devem estar na mesma rede; VPN, isolamento Wi‑Fi e firewall podem bloquear. Libere tráfego UDP de entrada/saída na porta escolhida para o executável.

## Regras

- **Uno:** 7 cartas, descarte inicial numérico, compra voluntária, apenas a carta comprada pode ser jogada, passar, +2/skip/reverse, wild/+4 atômicos, +4 apenas sem carta da cor ativa, declaração Uno e penalidade automática de duas; sem stacking/desafio.
- **Caxeta:** 9 cartas, compra e descarte, vira define o próximo rank/naipe como curinga, trincas e sequências sem sobreposição resolvidas por backtracking, batida de 9 perde 1 vida e batida de 10 com sequência 4+ perde 2; 7 ou 10 vidas.
- **Truco Paulista:** ordem 4–3, vira/manilha com Paus mais forte, três vazas, empates fechados, pedidos 3/6/9/12, aceitar/correr/aumentar e equipes opostas por assento; vence em 12.

## Testes

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --script res://tests/scene_smoke_runner.gd
```

Os testes foram criados, mas **não foram executados neste ambiente**, que não possui Godot. Consulte [`LOCAL_VALIDATION.md`](LOCAL_VALIDATION.md) para smoke de rede, teste manual em dois PCs e exportação.

## Exportar Windows

Instale templates 4.5.1 e execute `godot --headless --path . --export-release "Windows Desktop" build/HubDeCartas.exe`. O preset inclui todos os recursos e embute o PCK.

## Solução de problemas e logs

Confirme versão idêntica, IP/porta, mesma rede, firewall UDP e ausência de isolamento de clientes. Em timeout, recrie a sala. Não publique dumps de memória nem logs do servidor em produção; logs de clientes não recebem mãos adversárias. O projeto não oferece Internet pública, reconexão, migração de host, bot, chat ou persistência.

## Assets e licença

A interface usa apenas controles, texto e símbolos do sistema; não há asset externo ou áudio licenciado.

## Interface e controles

A apresentação usa mesa de feltro verde-petróleo, painéis translúcidos, detalhes dourados e cartas desenhadas proceduralmente. Cartas tradicionais têm frente marfim, rank e naipe; cartas Uno usam cores vivas e símbolos próprios; o verso geométrico “HC” nunca revela dados. A mesa se reorganiza por `Container`, a mão possui rolagem horizontal, adversários mostram assento e até cinco miniaturas de verso com a contagem real.

Todas as mesas usam deliberadamente confirmação em dois passos: **primeiro clique na carta para selecioná-la; depois confirme no botão principal** (**Jogar carta** ou **Descartar carta**). A carta escolhida sobe, ganha contorno dourado e seu nome aparece no HUD. Clique nela outra vez ou pressione `Esc` para cancelar; `Enter` confirma somente quando o botão principal estiver habilitado. O contorno verde discreto é apenas uma dica de jogada legal. Durante a confirmação, novos cliques são ignorados e um timeout de oito segundos devolve os controles sem reenviar a ação.

- **Uno:** no seu turno, selecione uma carta compatível com a cor, número ou símbolo e confirme em **Jogar carta**. Uma carta incompatível pode ser inspecionada, mas não confirmada. **Comprar carta** aparece na jogada normal e **Passar** após uma compra jogável. Ao confirmar um curinga, escolha vermelho, amarelo, verde ou azul na janela central; cancelar não envia nada. **Declarar Uno** só é oferecido quando a jogada deixará uma carta.
- **Caxeta:** siga a instrução da rodada: (1) **Comprar do monte** ou **Comprar descarte**, (2) selecionar uma carta e (3) confirmar em **Descartar carta**. Não é possível descartar antes da compra. **Bater ao descartar** viaja na mesma ação atômica e **Bater com 10** valida a mão completa.
- **Truco:** durante a vaza, selecione e confirme em **Jogar carta**. **Pedir Truco** respeita turno, valor e equipe do último aumento. Enquanto houver pedido, jogar fica bloqueado e somente a equipe respondente pode usar **Aceitar**, **Correr** ou **Aumentar**. Vira, manilha, vaza, valor da mão e placar ficam no centro.

Host e cliente seguem a mesma confirmação assíncrona. Uma rejeição mostra uma explicação amigável e reabilita a mesa; perda de conexão também cancela qualquer espera. Para validar em LAN, use duas instâncias/computadores conforme `LOCAL_VALIDATION.md`.

O menu inclui **Como jogar**, com abas para os três jogos e LAN. Nenhuma tela final apresenta snapshot, JSON ou dicionário interno. Consulte [`TEST_MATRIX.md`](TEST_MATRIX.md) e [`INITIAL_INVENTORY.md`](INITIAL_INVENTORY.md).
