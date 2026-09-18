# Sons

Anotacoes sobre audio das armas. Entra na Fase 3 (efeitos); nada aqui e implementado antes.

## Feito

- Layout dos sons em `Assets/Sounds`, colocados a mao pelo Gabriel (o `ImportWeapon` que os
  tirava do modelo saiu com os comandos na alpha.24): `Fire` da arma em
  `Assets/Sounds/<Arma>/Fire` (um Sound, ou uma pasta `Fire` com as camadas
  `FireBass`/`FireSmoke`/`FireSmokeEcho` do Viethin); os outros compartilhados em
  `Assets/Sounds/<Nome>` (`Selector`, recarga, vazio, equipar).

- **Primeiros sons tocando** (Gabriel, 17/09, alpha.28). `Client/Controllers/SoundController`:
  slot resolvido por `cfg.Sounds[slot]` (nome de um filho de `Assets/Sounds`), depois pasta da
  arma (`Assets/Sounds/<Model>/<Slot>`, tambem por `Name`/`DisplayName`), depois a raiz
  `Assets/Sounds/<Slot>`; Sound ou Folder de Sounds (camadas). `Fire` por arma, no `Handle`
  do atirador (proprio pelo `LocalShot`, os outros pelo `ShotFired`); `ModeSelect` ao trocar
  o modo de tiro (so quem trocou); `RemoveMag` e, quando acaba, `InsertMag` ao comecar o
  reload (so o dono; marcadores na animacao depois, pedido dele). Clone no `Handle`, destruido
  no `Ended`. `Settings.Sounds.Enabled`.

## Decidido com o Gabriel (14/09)

- Som de tiro **individual por arma**; os demais (recarga, seletor, vazio, equipar) sao os
  mesmos para todas. O Gabriel vai organizar os arquivos depois de importar tudo.
- Qualidade sonora e requisito, nao detalhe. Tres camadas por tiro:
  - **perto**: o `Fire` da arma, no cano do atirador;
  - **longe**: variante para quem ouve de longe (eco/estalo abafado), escolhida pela distancia
    entre ouvinte e cano, com crossfade por faixa (`Settings.Sounds.DistantFrom`);
  - **raspao**: bala passando perto do ouvinte (o `Pass` do Viethin): quando a trajetoria do
    tiro cruza a menos de N studs da camera de um client que nao e o atirador, toca um
    "crack/whiz" curto na posicao mais proxima da trajetoria. Vem do `ShotFired`, que ja
    carrega origem e fim de cada pellet; nenhum remote novo.

## Para depois

- Reload dos outros jogadores: o `State` so vai ao dono, entao `RemoveMag`/`InsertMag` so
  tocam para quem recarrega. Precisa de um aviso do servidor (ou enganchar a track de
  `Reload` replicada nos outros Animators).
- Marcadores da animacao de reload (`KeyframeMarker`) no lugar da sequencia por `Ended`.
- Camadas de distancia e raspao descritas acima.
- Impactos por material (metal, madeira, carne) e som de cartucho caindo.
- Oclusao simples (parede entre ouvinte e cano abafa) so se o custo compensar.
