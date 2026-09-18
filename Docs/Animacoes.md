# Animacoes e cadencia

Anotacoes de pedidos fora da fase atual sobre animacao e o que ela controla. A Fase 4 do
`PLANO.md` e onde isso entra.

## Feito

- Um portao so no client, `WeaponController.CanFire()`: pronto, com bala, vivo e fora do intervalo. Clique
  indisponivel e descartado; segurar o gatilho durante recarga ou troca nao retoma o tiro. O servidor
  ja descartava tudo fora das regras dele e continua (0.2.0-alpha.4).
- Clique durante o intervalo entre tiros e ignorado (nao fica em fila para disparar quando o
  intervalo acaba). Vale para Semi e Burst (0.2.0-alpha.3).
- **Juntas vem dentro do modelo** (16/09, alpha.24). A animacao aplica pose por nome de parte
  no Motor6D cujo `Part1` e aquela parte, entao o que precisa bater entre o rig do Gabriel e o
  jogo sao nomes, pares ligados e `C0`/`C1`. Em vez de o codigo recriar isso, o modelo copiado
  do rig traz os Motor6D: todo motor com `Part1` dentro do modelo e `Part0` vazio ou apontando
  para o rig e "junta de rig"; `Sanitize` preserva e `Attach` preenche `Part0` com a parte do
  boneco de mesmo nome da que o motor ainda aponta (duplicar com Ctrl+D ou arrastar mantem),
  senao pelo nome do motor, senao `Rig.WeaponJoints` (`Handle` -> mao). Nomes das partes da
  arma sao os dele (`Mag`, `MagTrash`, `Bolt`...), o codigo nao assume nenhum. `Magazine` <-
  `Handle` e interno e fica. `Grip` saiu do config; modelo sem motor para o boneco
  (placeholder) ganha um padrao no `Handle`. Regra para ele: tudo da arma dentro de um Model
  so antes de duplicar (motor do `Handle` arrastado para dentro se o plugin deixou no braco).
  Motor invertido (`Part0` na arma, `Part1` no braco) e weld comum para fora do modelo sao
  descartados com aviso no Output.
- **Pentes do reload sao do rig, nao da arma** (Gabriel, 16/09). `Mag` e `MagTrash` ficam
  soltos no rig `Rifles`, ao lado do `FN FNC`, presos ao `Left Arm` por Motor6D, e so o clip
  de `Reload` mexe neles. Vao para `Assets/Reload/<Classe>` (Model com as partes e seus
  motores dentro; `Assets/Reload/Weapons/<Nome>` quando uma arma precisar do seu). `Clone`
  copia esse Model para dentro da arma equipada como sub-model `Reload`, invisivel
  (Transparency 1), e `Attach` encaixa os motores no boneco igual aos da arma. Um pente so por
  classe: toda rifle mostra o mesmo `Mag` na mao, salvo override por arma.

- **Fase 4 escrita** (16/09, alpha.25). `Shared/Animations` toca os slots: um set por arma,
  ligado ao Animator do boneco e ao do viewmodel, slot em loop = stance (troca a que toca),
  o resto = acao por cima com `AdjustSpeed` para casar com o timer do config. Prioridade e loop
  pelo nome do slot (`Assets/Manifest`); slot ausente e ignorado e os bracos ficam na `Pose`.
  A maquina de estados decidida abaixo entrou inteira: equipar cai em `Relaxed`, `Keys.Ready`
  (F, no lugar do `Inspect`) pede `Ready` pelo remote `Relax` e volta, `Combat` so aceita
  tiro/mira em `Ready`, reload vale em `Relaxed` e em `Ready` e devolve ao mesmo estado. HUD
  mostra `Strings.Relaxed` e esconde a mira com a arma baixa. Com Backpack ligado, a track
  `toolnone` do `Animate` e parada enquanto a stance toca
  (`Settings.Animations.OverrideToolTrack`).
- **Sem tempo de equipping** (Gabriel, 16/09, alpha.25). O estado `Equipping` saiu: sacar e
  instantaneo e cai direto em `Relaxed`. O `EquipTime` fica so como duracao para reamostrar o
  clip opcional de `Equip`. Motivo: a guarda contra troca-e-tira ja e a tecla F, entao o timer
  nao protegia nada e so atrasava.
- **Reload e animacao juntos** (Gabriel, 16/09, alpha.25). O `AdjustSpeed` so acontecia se o
  clip ja estivesse carregado no frame em que comecou, entao na pratica o reload tocava na
  velocidade natural e terminava antes do timer. Agora ele ajusta assim que o `Length` aparece.
  Alternativa que o Gabriel pode preferir: ligar `Settings.Animations.LogSlots`, ler no Output
  o tamanho real de cada clip e por esse numero em `Reload.Time`, deixando a animacao na
  velocidade em que foi feita.
- **Pentes extras cancelados** (Gabriel, 16/09, alpha.25). Ele vai fazer um reload simples,
  sem pente na mao esquerda, e pediu para apagar tudo que servia para isso. Saiu do codigo:
  `Assets/Reload/<Classe>`, o sub-model `Reload` invisivel dentro da arma,
  `WeaponModel.ReloadParts`/`ApplyVisibility`, `Reload.Swap`/`Swaps`/`Rest` no config, o
  `ReloadPartsController` e o suporte a marker no `Shared/Animations` (`OnMarker`,
  `SlotOfTrack`). O reload agora e um clip so, nos bracos e nas partes da propria arma
  (`Magazine`, `Bolt`), e `Reload` no config volta a ser `Mode`/`Time`/`EmptyTime`.
  Motivo tecnico que levou a isso: trilha de propriedade (Transparency) e parte solta por
  CFrame no Moon nao saem no export da KeyframeSequence, entao a troca visual precisaria de
  marker ou timer no codigo, e ele preferiu simplificar a animacao. Se um dia voltar, esta no
  historico do git (alpha.24/alpha.25) e nas notas acima.
- **Bracos so pelo clip** (Gabriel, 17/09, alpha.26). Nenhum ajuste de codigo posiciona os
  bracos em 1a pessoa: `Settings.Viewmodel.Offset`, a `Pose` de descanso e o reposicionamento
  do viewmodel na mira sairam. O clone fica no lugar exato do corpo e, ao mirar, a camera vai
  ate o `Sight`. Slot ausente = braco caido (sinal de que falta clip). Detalhes em
  [Miras.md](Miras.md).
- **O clip e o timer** (Gabriel, 17/09, alpha.27). O reload demorava mais que a animacao: o
  servidor esperava `Reload.Time` (2.0s) e o `AdjustSpeed` que devia esticar o clip ate la
  dependia do `Length` da track chegar a tempo. Invertido: `Animations.ClipLength` le o
  ultimo keyframe da KeyframeSequence em `Assets/Animations` (funciona no servidor e fora do
  Studio, desde que as KeyframeSequences fiquem em `Assets` depois de publicar) e `Combat`
  segura `Reloading` exatamente esse tempo (`Animations.ReloadTime`); todo clip toca na
  velocidade em que foi feito. Sairam `Settings.Animations.MatchConfigTime`, a opcao
  `Duration` do `Set:Play` e `EquipTime` do config. `Reload.Time`/`EmptyTime` so valem para
  arma sem clip.
- **Pitch do olhar em 3a pessoa** (Gabriel, 17/09, alpha.27). Armado (`Ready`: Idle ou Aim, e
  reload que comecou dali), ombros e pescoco giram com o pitch da camera por cima do clip
  (`Client/Controllers/LookController`, `Rig.LookJoints`), em `PreSimulation` depois do
  Animator escrever e com o `Transform` devolvido em `PreAnimation` para nao acumular. Motor6D
  nao replica: o client manda o pitch pelo remote nao confiavel `Look` (graus inteiros,
  `Settings.Look.SendRate`/s, so quando muda) e o servidor repassa `LookUpdate`; cada client
  gira os outros bonecos com `Smoothing` e nivela apos `Timeout`. Em `Relaxed` nada gira e a
  camera e a da Roblox (sem shift lock): o pacote so assume a camera armado
  (`Client.IsArmed()`, campo `Armed` no snapshot).

## Decidido para a Fase 4 (14/09)

- **Maquina de estados da arma** (Gabriel, 14/09). Sem animacao de `Equip`: selecionar a Tool
  leva direto a `Relaxed` (arma na mao, baixa, desarmada). Tecla F (`Keys.Ready`, no lugar de
  `Inspect`) alterna `Relaxed` <-> `Idle`; em `Idle` pode atirar, segurar o botao direito vai
  para `Aim`, soltar volta. `Reload` funciona em `Relaxed` e em `Idle` e devolve ao mesmo
  estado. Em `Relaxed`: sem `Aim`, sem `Fire` (o servidor recusa; o client nem manda). Sem
  `Sprint` (so muda velocidade; pernas ficam com o `Animate`), sem `Inspect`, sem `Unequip`.
  No servidor: `EquipState` ganha `Relaxed`; `Ready` passa a exigir o F; `Combat` so aceita
  `Fire`/`Aim` em `Ready`; `EquipTime` continua como guarda contra troca-e-tira, sem animacao.
  Remote novo `Relax(boolean)` no padrao do `Aim`. Suposicoes a confirmar: F e toggle; nao ha
  volta automatica para `Relaxed` por tempo.
- Slots com clip: `Relaxed`, `Idle`, `Aim`, `Reload` (+ `ReloadEmpty` opcional). Sem `Fire`
  (Gabriel, 15/09): o tiro e o kick de camera, a mola do viewmodel e os efeitos, nao tem clip.
  Prioridades: `Relaxed`/`Idle` Idle, `Aim` Movement, `Reload` Action.
- Estado (15/09): `Relaxed`, `Idle` e `Aim` do Rifle ja animados pelo Gabriel; falta `Reload`.
- **Reload com pentes extras** (Gabriel, 15/09, como nos videos). `Magazine` fica na arma
  (Motor6D do `Handle`); os extras sao o kit `Assets/Reload/<Classe>` (feito em 16/09, ver
  "Feito"). No rig `Rifles` sao dois: `Mag` (o novo, que a mao esquerda traz) e `MagTrash`
  (suposicao: o vazio que cai; confirmar). KeyframeSequence nao anima Transparency, entao a
  troca visual e codigo nos markers do clip: `MagOut` esconde `Magazine` e mostra `MagTrash`,
  `MagDrop` esconde `MagTrash` e mostra `Mag`, `MagIn` esconde `Mag` e mostra `Magazine`
  (nomes dos markers a combinar com ele; Transparency local no client, para nao brigar com o
  LocalTransparencyModifier da 1a pessoa; fora do reload o kit inteiro fica em Transparency
  1, que e como `Clone` ja o entrega). Os mesmos markers (`MagOut`, `MagIn`, `Bolt`) dao o
  tempo dos sons. Se o Moon nao exportar markers, inserir `KeyframeMarker` a mao no Keyframe
  da KeyframeSequence exportada.
  Codigo da Fase 4: quais partes cada marker esconde/mostra vem do config, nao de nomes
  fixos; um observador de `Animator.AnimationPlayed` em cada boneco (proprio, viewmodel e dos
  outros jogadores) engancha os markers da track de Reload e acha o kit por
  `WeaponModel.ReloadParts(model)`. A confirmar no Test com 2 jogadores:
  `GetMarkerReachedSignal` dispara em track replicada.
- **Os pentes nao sao animados** (16/09). No Moon o Gabriel tinha adicionado `Mag` e
  `MagTrash` como itens soltos (CFrame, so toca no Moon) e keyado Transparency no `Magazine`
  (trilha de propriedade, idem): nada disso sai no export, so pose de Motor6D. Nao precisa:
  como nos videos, cada pente fica soldado na mao numa pega fixa e so aparece/some. Ele cria um
  Motor6D `Left Arm` -> `Mag` no frame em que a mao segura o pente (o Easy Weld grava a pega
  em `C0`/`C1`), idem `MagTrash`, tira os dois da timeline e duplica para
  `Assets/Reload/Rifle`. A Transparency vira os markers `MagOut`/`MagDrop`/`MagIn`.
- `Aim` e por classe: em 1a pessoa o `ViewmodelController` alinha o `Sight` ao centro por cima
  de qualquer clip, entao a diferenca de mira entre armas e o attachment, nao a animacao.
- `Reload` por arma so quando o mecanismo difere (`Assets/Animations/Weapons/<Nome>/Reload`);
  o `Magazine` e junta pelo nome, entao o `Reload` da classe move o pente de qualquer arma.
- Com Backpack ligado a Tool fica no boneco e o `Animate` toca `toolnone` (prioridade Action)
  no braco direito: `Idle`/`Aim`/`Relaxed` precisam vencer isso no `WeaponController` (tocar
  com prioridade Action ou parar o track `toolnone` do Animate).

## Para depois (Fase 4)

- **Rigs feitos a mao pelo Gabriel** (15/09). Ele monta os rigs de animacao e prende as armas
  sozinho (Easy Weld / juntas manuais). `Attach` ja reproduz a junta dele porque ela viaja no
  modelo (ver "Feito"). Lembrete: so Motor6D vira track no editor; braco -> `Handle`,
  `Handle` -> `Magazine` e braco esquerdo -> `Mag`/`MagTrash` precisam ser Motor6D, o resto
  pode ser weld. Falta ver a arvore real do FN FNC rigado para confirmar os nomes.
- **Sem comandos de Studio** (Gabriel, 15/09). A pasta `Dev/` foi apagada (alpha.24). Nada no
  pacote cria, importa ou edita instancia: modelo, attachments, juntas, KeyframeSequences e sons
  entram a mao no Studio e o codigo so le. O loader da Fase 4 aplica prioridade e loop pelo nome
  do slot (`Assets/Manifest.luau`), entao a KeyframeSequence so precisa do nome certo em
  `Assets/Animations/<Classe>/`.
- **Moon Animator** (15/09). O export do Moon e uma KeyframeSequence, igual ao save do editor
  da Roblox: renomear pelo slot e arrastar para `Assets/Animations/Rifle/`. A KeyframeSequence
  guarda pose por nome de parte por cima da junta, entao o rig dele precisa dos nomes do jogo
  (`Right Arm`, `Left Arm`, `Torso`, `Handle`, `Magazine`, `Mag`, `MagTrash`); `C0`/`C1` batem
  sozinhos porque o Motor6D vai junto com o modelo. Recurso do Moon que anima CFrame de parte
  solta nao exporta.

- **Cadencia guiada pela animacao** (pedido em 13/09, cancelado em 15/09): dependia de um clip
  `Fire` e ele nao vai existir. O intervalo entre tiros continua so pelo `ShotInterval` do
  config. Se um dia uma arma de ferrolho precisar de animacao entre tiros, volta como slot novo
  com a regra de sempre: o servidor confia no timer do config, nunca no fim da animacao.
