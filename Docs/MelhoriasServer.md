# Melhorias do servidor

Anotacoes sobre o lado server (validacao, replicacao, depuracao). Nada aqui e implementado
fora do plano, salvo o marcado como feito.

## Feito

- Dano por distancia ja existe: `Damage.FalloffStart`, `FalloffEnd` e `FalloffMultiplier` por arma
  (interpolacao linear entre inicio e fim, aplicado antes das zonas e da armadura em `Combat`).
- `Dev.SpawnDummy` renasce o dummy 3 s depois de morrer, no mesmo lugar; `Dev.ClearDummies` remove todos.
- `Settings.Debug.ServerTracers`: no Studio, o servidor desenha uma linha vermelha por tiro do
  cano ate o ponto de impacto, para a tela Server mostrar onde a bala foi. Nunca roda em jogo
  publicado (alpha.9).

## Para depois

- O Gabriel quer que "o servidor veja os tiros": hoje so os clients desenham. Se um dia for
  preciso replicacao visual pelo servidor (NPCs atirando, replays), entra como opcao com custo
  medido, com LOD pelo nivel de qualidade.
- Lag compensation (ring buffer de posicoes) — previsto como v2 no plano.
- Kick/ban por abuso com log externo (hoje so contador + kick opcional).
