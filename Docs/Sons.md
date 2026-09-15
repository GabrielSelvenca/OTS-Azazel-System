# Sons

Anotacoes sobre audio das armas. Entra na Fase 3 (efeitos); nada aqui e implementado antes.

## Feito

- `ImportWeapon` tira os sons do modelo: `Fire*` da arma vai para `Assets/Sounds/<Arma>/Fire`
  (um Sound, ou uma pasta `Fire` com as camadas `FireBass`/`FireSmoke`/`FireSmokeEcho` do
  Viethin); os outros nomes sao compartilhados em `Assets/Sounds/<Nome>`, o primeiro import
  ganha. `FireSelect` vira `Selector` (alpha.17).

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

- Impactos por material (metal, madeira, carne) e som de cartucho caindo.
- Oclusao simples (parede entre ouvinte e cano abafa) so se o custo compensar.
