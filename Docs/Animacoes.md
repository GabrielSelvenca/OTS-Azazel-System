# Animacoes e cadencia

Anotacoes de pedidos fora da fase atual sobre animacao e o que ela controla. A Fase 4 do
`PLANO.md` e onde isso entra.

## Feito

- Um portao so no client, `WeaponController.CanFire()`: pronto, com bala, vivo e fora do intervalo. Clique
  indisponivel e descartado; segurar o gatilho durante recarga ou troca nao retoma o tiro. O servidor
  ja descartava tudo fora das regras dele e continua (0.2.0-alpha.4).
- Clique durante o intervalo entre tiros e ignorado (nao fica em fila para disparar quando o
  intervalo acaba). Vale para Semi e Burst (0.2.0-alpha.3).

## Decidido para a Fase 4 (14/09)

- Slot `Relaxed` (prioridade Idle, loop) entra no Manifest (alpha.20): arma baixa depois de N
  segundos sem tiro nem mira, qualquer input volta para `Idle`, e o tiro nunca espera a
  transicao (a bala sai, a animacao de levantar toca por cima).
- `Aim` e por classe: em 1a pessoa o `ViewmodelController` alinha o `Sight` ao centro por cima
  de qualquer clip, entao a diferenca de mira entre armas e o attachment, nao a animacao.
- `Reload` por arma so quando o mecanismo difere (`Assets/Animations/Weapons/<Nome>/Reload`);
  o `Magazine` e junta pelo nome, entao o `Reload` da classe move o pente de qualquer arma.
- Com Backpack ligado a Tool fica no boneco e o `Animate` toca `toolnone` (prioridade Action)
  no braco direito: `Idle`/`Aim`/`Relaxed` precisam vencer isso no `WeaponController` (tocar
  com prioridade Action ou parar o track `toolnone` do Animate).

## Para depois (Fase 4)

- **Cadencia guiada pela animacao** (pedido em 2026-09-13). Arma com atraso entre tiros (sniper
  de ferrolho, shotgun de bomba) tem uma animacao no meio; o proximo tiro so libera quando o slot
  `Fire` termina, nao por um timer solto. Reload cancela a animacao de `Fire` e o intervalo, e
  comeca a recarga na hora. Qualquer outro clique durante `Fire` e ignorado.
- Como fazer sem abrir brecha: o servidor nao pode confiar em "a animacao acabou" vindo do client,
  entao o tempo do config (`ShotInterval`, `Reload.Time`, `EquipTime`) continua sendo a regra no
  servidor. O client usa a animacao como gatilho visual e o `AnimationSet` ajusta a velocidade do
  clip (`AdjustSpeed`) para o comprimento da KeyframeSequence bater com o tempo do config. Assim
  o fim da animacao e o fim do intervalo sao o mesmo instante para o jogador.
- Alternativa se o Gabriel preferir animar sem se preocupar com tempo: comando de Studio que le o
  comprimento de cada KeyframeSequence e grava `ShotInterval`/`Reload.Time` no config da arma.
