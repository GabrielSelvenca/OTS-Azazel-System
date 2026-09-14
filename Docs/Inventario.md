# Inventario e Backpack

Anotacoes de pedidos fora do plano principal sobre inventario, hotbar e equipar/desequipar.
Nada daqui entra antes do plano fechar.

## Feito

- Tecla `0` desequipa (estado `Holstered`), `Equip(player, 0)` na API; teclas 1-5 trocam de slot.
- Armas nao sao Tools: Model preso ao `Right Arm` por Motor6D `Handle`.
- Hotbar em codigo e barras de armadura removidas do HUD (alpha.5). Equipamento nao tem vida por
  enquanto (`HelmetLight`/`VestLight` sem `Durability`); o suporte continua no config e no
  Inventory para quando voltar.
- **Backpack padrao = inventario** (alpha.19, pedido de 14/09). `Systems/Backpack`, ligado por
  `Settings.Server.UseBackpack`. Ao contrario do rascunho antigo, a **Tool e a fonte da verdade**:
  qualquer Tool com atributo `AzazelWeapon` (ou `Name` igual a `Name`/`DisplayName` de um config)
  que entre no Backpack ou no boneco ganha um slot; ao sair, devolve. A Tool fica equipada no
  boneco normalmente (sem Handle, `RequiresHandle = false`, `CanBeDropped = false`), entao a
  hotbar da Roblox mostra o destaque certo e apertar o mesmo numero desequipa. `Tool.Equipped`
  -> `Inventory.Equip(slot)`; `Tool.Unequipped` -> `Equip(0)` se nenhuma outra Tool estiver na
  mao. A API (`GiveWeapon`, `RemoveWeapon`, `SetLoadout`, `Equip`) cria/destroi/equipa as Tools.
  Teclas 1-5 e 0 do Azazel ficam desligadas nesse modo. Spawn sem loadout
  (`GiveDefaultLoadoutOnSpawn = false`): a UI de armas do jogo entrega a Tool.
- Efeito colateral bom: com a Tool no boneco, o `Animate` da Roblox toca `toolnone` e levanta o
  braco direito em 3a pessoa, entao a arma fica erguida ate o `Idle` da Fase 4 existir. Na Fase
  4 o `Idle` precisa de prioridade Action para vencer o `toolnone` no braco.

## Para depois

- **Desequipar = ficar "normal"**: com slot 0, esconder toda a UI do Azazel (crosshair, municao,
  hotbar, armadura), devolver a camera para o padrao da Roblox (`CameraType.Custom`, mouse
  livre, `AutoRotate = true`) e parar os binds de tiro/mira. Ao equipar qualquer slot tudo volta
  (camera OTS, lock, HUD). Hoje a camera OTS e o HUD ficam ativos mesmo em `Holstered`.
- Opcao em `Settings` para o jogo escolher: hotbar sempre visivel ou so com arma equipada.
