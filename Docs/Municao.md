# Municao

## Feito

- `Settings.Server.InfiniteAmmo = true` por padrao: a reserva nunca acaba, recarregar sempre
  enche o pente, HUD mostra `/ ∞` (alpha.6). O pente e a recarga continuam existindo porque
  dao ritmo ao tiro e a recarga e um dos slots de animacao.

## Para depois

- Se o Gabriel quiser tirar a recarga tambem, entra uma chave (`Reload.Mode = "None"`).
- Economia de municao (pegar municao no mapa, tipos de bala, caixa de municao) so se o jogo
  pedir; o modelo de dados ja tem `Reserve` e `Modifiers.Reserve` para isso.
