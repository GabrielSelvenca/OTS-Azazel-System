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

- **Nao controlamos mais a Backpack** (Gabriel, 16/09, alpha.25). O `Systems/Backpack` virou
  observador: nao cria, nao destroi, nao edita e nao equipa/desequipa Tool nenhuma, e nao
  entrega loadout nesse modo. Ele so olha o que esta na mao do boneco; Tool que nomeia uma arma
  (atributo `AzazelWeapon`, `Name` igual a `Name`/`DisplayName`) coloca a arma na mao enquanto
  estiver equipada, o resto e ignorado. O slot e contabilidade (municao, fire mode, spray) e
  fica com a Tool ate ela ser destruida, entao guardar e sacar mantem o pente. A API
  (`GiveWeapon`, `RemoveWeapon`, `SetLoadout`, `Equip`) fala direto com o `Inventory`, sem
  `EquipRouter`. Consequencia para o Gabriel: **Tool sem `Handle` precisa de
  `RequiresHandle = false` nela mesma** (era o pacote que marcava isso).
  Motivo: o pacote equipava a Tool no spawn e um milissegundo depois ela sumia (`is under
  nothing`), e o dono da Tool e o jogo, nao o pacote.
- **Desequipar = ficar "normal"** (feito em 16/09, alpha.25). Sem arma na mao a camera volta
  para a padrao da Roblox (`CameraType.Custom`, cursor, zoom da Roblox, `AutoRotate = true`),
  `V` e a troca de ombro nao fazem nada, e o painel de municao, a linha de status e a mira
  somem; a mira so aparece em `Ready`. Ao equipar, a camera assume a partir do angulo em que a
  da Roblox estava, sem tranco.

## Para depois

- Opcao em `Settings` para o jogo escolher: hotbar sempre visivel ou so com arma equipada.
