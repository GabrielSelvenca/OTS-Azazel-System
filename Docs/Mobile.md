# Mobile

Pedido do Gabriel (17/09): depois dos ajustes de animacao e camera, o que falta no pacote e
responsividade da HUD e controles/botoes na tela para celular. Nada disso existe ainda.

## Feito

- Nada. O `InputController` tem tabela `Settings.Keys.Gamepad` para controle, mas nenhum
  toque; a HUD e fixa em pixels (`AmmoPanel` 220x92 no canto inferior direito).

## Para depois

- **Responsividade da HUD.** Escalar o painel de municao e a mira pelo tamanho da tela
  (`UIScale` pelo menor lado do viewport, ou tamanhos em `UDim2` com escala). Testar no
  emulador de dispositivos do Studio.
- **Controles de toque.** Botoes na tela para atirar, mirar, recarregar, armar/baixar (F),
  trocar de ombro e alternar 1a/3a pessoa; disparo ao tocar na metade direita da tela e
  camera pelo arraste, como os shooters mobile da Roblox fazem. Tudo pelo bus
  (`Client.Signals.*Input`), sem tocar no `WeaponController`. Esconder os botoes quando ha
  teclado/mouse (`UserInputService.TouchEnabled` e `KeyboardEnabled`).
- **Sensibilidade e zona morta** proprias de toque em `Settings.Keys` (ou uma tabela
  `Settings.Touch`).
