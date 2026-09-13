# Inventario e Backpack

Anotacoes de pedidos fora do plano principal sobre inventario, hotbar e equipar/desequipar.
Nada daqui entra antes do plano fechar.

## Feito

- Hotbar de 5 slots em codigo, tecla `0` desequipa (estado `Holstered`), `Equip(player, 0)` na API.
- Armas nao sao Tools: Model preso ao `Right Arm` por Motor6D `Handle`.

## Para depois

- **Armas na Backpack sem serem Tool comum** (pedido em 2026-09-13). Ideia: cada arma do jogador
  vira um item no `Backpack` (Folder/ObjectValue com atributos, ou Tool com `Enabled = false`
  e `RequiresHandle = false` so como marcador) para o jogo que integra poder ler o inventario
  pelo Backpack. A UI padrao da Roblox nao mostra nada que nao seja Tool, entao Folder e a
  opcao segura. O Inventory do server continua sendo a fonte da verdade.
- **Desequipar = ficar "normal"**: com slot 0, esconder toda a UI do Azazel (crosshair, municao,
  hotbar, armadura), devolver a camera para o padrao da Roblox (`CameraType.Custom`, mouse
  livre, `AutoRotate = true`) e parar os binds de tiro/mira. Ao equipar qualquer slot tudo volta
  (camera OTS, lock, HUD). Hoje a camera OTS e o HUD ficam ativos mesmo em `Holstered`.
- Opcao em `Settings` para o jogo escolher: hotbar sempre visivel ou so com arma equipada.
