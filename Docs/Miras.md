# Miras

Como a mira de 1a pessoa e alinhada, o que o Gabriel faz a mao por arma e o que fica para
depois.

## Feito

- Em 1a pessoa o `ViewmodelController` recoloca a raiz do viewmodel a cada frame para o
  attachment `Sight` da arma cair no eixo da camera, a `Ads.SightDistance` na frente dela, por
  cima de qualquer clip. E o mesmo principio do `AimPart` do ACS/Viethin: a pose de `Aim` nao
  precisa de valores exatos, so precisa parecer que mira. Em 3a pessoa nao ha viewmodel: mirar
  so muda FOV, distancia e ombro, e o tiro sempre sai do CFrame da camera.
- Um `Sight` por modelo, Attachment no `Handle`, no ponto do olho atras da alca, na linha
  alca/maca. Nao e ajuste por tentativa: coloca uma vez por modelo e pronto. Sem `Sight` o
  codigo usa `Ads.ViewmodelOffset` da arma.
- Corpo real visivel em 1a pessoa (alpha.24): a cabeca nao entra no viewmodel e a camera fica
  fixa na raiz, entao inclinar a cabeca na pose de `Aim` e so cosmetico em 3a pessoa.
- **Viewmodel no lugar do corpo real** (16/09, alpha.25). O clone era colocado num offset
  chutado (`CFrame.new(0, -1.9, -0.5)`), de quando nao havia animacao para comparar: ficava
  0.4 abaixo e meio stud a frente do corpo, entao o `Idle`/`Aim` do rig apareciam tortos em 1a
  pessoa. Agora a raiz vai no inverso de `Camera.FirstPersonOffset` (a camera esta na cabeca,
  a raiz desce a mesma distancia) e `Settings.Viewmodel.Offset` e so o ajuste fino, zero por
  padrao. Falta o Gabriel colocar o attachment `Sight` no `FN FNC`; sem ele o ADS cai no chute
  de `Ads.ViewmodelOffset`.
- **Sem ajuste nenhum: a camera vai ate o `Sight`** (Gabriel, 17/09, alpha.26). Inverteu o
  principio acima. O clone fica sempre no lugar exato do corpo real (raiz = olho menos
  `Camera.FirstPersonOffset`, girado com a camera em torno do olho) e nada em codigo posiciona
  os bracos: sairam `Settings.Viewmodel.Offset`, `WeaponConfig.Defaults.Pose` (e
  `Rig.PoseJoints`), `Ads.SightDistance`, `Ads.ViewmodelOffset` e o `sightCFrame` que movia o
  viewmodel na mira. Ao mirar quem se move e a camera: em `Ads.Time` o olho desliza da cabeca
  ate o ponto exato do attachment `Sight` (o `ViewmodelController` publica
  `Client.SightOffset`, o `CameraController` soma no ponto do olho em 1a pessoa). Sem `Sight`
  a camera fica na cabeca e o clip e o que se ve. Consequencia para o Gabriel: `Relaxed`,
  `Idle` e `Aim` sao animados olhando da cabeca do rig (centro do `Head`, 1.5 stud acima do
  centro do `Torso`), e o ciclo e clip -> `Assets/Animations` -> Play, sem numero. O
  `Sight` continua um por modelo, no ponto do olho atras da alca.
- **`Sight` e `Muzzle` como Part ou Attachment** (17/09, alpha.27). O `Sight` do FN FNC do
  Gabriel e um Part invisivel, nao um Attachment, e o codigo so procurava Attachment: a camera
  nunca saia da cabeca. `WeaponModel.FindPoint` aceita os dois (Part solto e soldado ao
  `Handle` pelo `Sanitize` como qualquer outro). Mirar em 1a pessoa com arma sem `Sight` avisa
  uma vez no Output.

## Para depois

- **Alinhar a rotacao tambem.** A camera vai ao ponto do `Sight` mas mantem a rotacao do
  mouse, entao o cano precisa estar paralelo a frente do torso na pose de `Aim`. Usar tambem
  a orientacao do `Sight` (eixo -Z pelo cano) exigiria girar o corpo em torno do olho ate o
  `Sight` apontar com a camera; e um ajuste de codigo, entao so se o Gabriel pedir.
- **`AimPart` do Viethin.** Os modelos do Viethin trazem um `AimPart` invisivel ja no ponto
  certo: criar um Attachment `Sight` no `Handle` com o mesmo CFrame (posicao e orientacao) e
  apagar a part. A mao, no Studio; nao ha import.
- **Miras diferentes por arma** (Gabriel, 15/09). Algumas armas terao opticas proprias, montadas
  uma a uma depois; por agora so as de ferro. Forma provavel: um `Sight` por optica no modelo e
  `Ads.SightDistance`/`Ads.Fov` por arma; lunetas continuam pelo `Ads.Scope`.
