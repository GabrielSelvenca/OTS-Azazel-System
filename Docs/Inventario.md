# Inventario e Backpack

Anotacoes de pedidos fora do plano principal sobre inventario, hotbar e equipar/desequipar.
Nada daqui entra antes do plano fechar.

## Feito

- Tecla `0` desequipa (estado `Holstered`), `Equip(player, 0)` na API; teclas 1-5 trocam de slot.
- Armas nao sao Tools: Model preso ao `Right Arm` por Motor6D `Handle`.
- Hotbar em codigo e barras de armadura removidas do HUD (alpha.5). Equipamento nao tem vida por
  enquanto (`HelmetLight`/`VestLight` sem `Durability`); o suporte continua no config e no
  Inventory para quando voltar.

## Para depois

- **Hotbar = Backpack padrao da Roblox** (pedido em 2026-09-13). A UI padrao so lista Tools, entao
  cada slot vira uma Tool marcadora no `Backpack` (`RequiresHandle = false`, `CanBeDropped = false`,
  `ToolTip = DisplayName`, sem Handle). Clicar/apertar o numero na UI da Roblox dispara
  `Tool.Equipped`; o server trata isso como `Equip(slot)` e devolve a Tool ao Backpack na hora,
  para a Roblox nao tentar segurar nada (a arma continua sendo o Model no Motor6D). Selecionar a
  Tool ja equipada = `Equip(0)`. O Inventory continua a fonte da verdade e cria/destroi as Tools
  ao dar/remover arma. Precisa checar: `Humanoid:UnequipTools()` sem flicker, ordem dos slots na
  UI (Backpack ordena por insercao), e desligar o Backpack quando o jogo quiser HUD propria.
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
