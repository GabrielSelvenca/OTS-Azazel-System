# Azazel OTS System — plano de fundacao

## Contexto

Gabriel quer um pacote de tiro em 1a/3a pessoa (OTS) para Roblox, reutilizavel em qualquer jogo,
100% via Script Sync, com R6 primeiro (R15 depois), animacoes feitas a mao por ele (nada
procedural), UI 100% em codigo, armas de packs gratuitos, equipamentos (capacete/colete) reduzindo
dano, versionamento semver com canais e git na raiz. O repo pode virar publico, entao seguranca
(servidor autoritativo, remotes fechados e validados) e requisito, nao detalhe.

Estado atual do diretorio: pastas de servico vazias; `Cons\Cons\` e um bundle local de 29
pacotes (fica local, entra no `.gitignore`). Nao ha git nem config.

Fatos verificados que moldam o desenho:
- KeyframeSequence embutida so toca **no Studio** (`KeyframeSequenceProvider:RegisterKeyframeSequence`
  gera id temporario). Em jogo publicado a animacao precisa estar publicada e com permissao para a
  experiencia (regra de 31/07/2025; animacao nunca e "uso aberto"). Logo: embutir KeyframeSequences
  + auto-registro no Studio + manifesto de ids preenchido por quem importa.
- Script Sync so sincroniza Script/LocalScript/ModuleScript/Folder. Models, KeyframeSequences,
  Sounds, GUIs e Remotes nascem por codigo ou a mao no Studio.
- O EB (`C:\dev\EB`) ja tem um Combat server-side com padroes bons para copiar: registro fechado de
  remotes, merge de config em 3 camadas, `interval*0.9` de tolerancia, origem a <= N studs da
  cabeca, spread em disco uniforme `rad(deg)*sqrt(random())`, `alphaFor(seconds, dt)`, `UIKit.New`.

## Decisoes fechadas com o Gabriel

| Tema | Decisao |
|---|---|
| 1a pessoa | **Viewmodel = clone do proprio rig R6** (Torso + bracos + arma) na Camera. Mesma animacao toca no viewmodel e no boneco real. |
| Animacoes | **KeyframeSequence embutida** em `Assets/Animations/<Class>/<Slot>`, auto-registro no Studio, manifesto `AnimationIds.luau` para o jogo publicado, comando que lista o que falta. |
| Tiro | **Hitscan reto** (sem fisica), modelo de precisao **estilo CS**: precisao base por arma, primeira bala mais precisa, spray abre segurando o gatilho e recupera ao soltar; spread sorteado **no servidor**. Tracer visual fino que viaja (nao "bloco em linha reta"). |
| Cons | Vendorar **so os modulos usados** em `ReplicatedStorage/Azazel/Packages/`. `Cons/` na raiz fica local, no `.gitignore`. |
| Camera | OTS com mouse travado, ombro configuravel + troca de ombro, boneco gira com a camera, **V** alterna 1a/3a, botao direito = ADS (FOV e distancia por arma). |
| Arma | **Model + Motor6D `Handle`** (Part0 = Right Arm, Part1 = Handle), sem Tool. Equipar/hotbar em codigo. |
| Animacoes por | **Classe** (Pistol, SMG, Rifle, Shotgun, Sniper) com **offset de encaixe por arma** (C1 do Motor6D). Arma pode sobrescrever slot. |
| Slots v1 | Idle, Fire, Reload, Equip (codigo preve tambem Aim, ReloadEmpty, Sprint, Inspect, Unequip; slot ausente e ignorado). |
| Armas v1 | Pistola (semi), SMG (auto), Fuzil (auto/semi), Shotgun (pellets), Sniper (scope). |
| Git | `git init` na raiz + primeiro commit e tag por mim. |
| Codigo | Tudo em ingles, comentarios minimos, nomes claros, 4 espacos, PascalCase (modulos/instancias/config) e camelCase (locais). Strings visiveis ao jogador em ingles numa tabela `Strings` sobrescrivel pelo jogo. |
| Docs | `README.md` (integrar/usar via codigo), `COMMITS.md` (padrao de commit humanizado), `CHANGELOG.md`. |

## Arquitetura

### Arvore (nomes do Script Sync)

```
OTS Azazel System/
  .gitignore  README.md  CHANGELOG.md  COMMITS.md  .githooks/pre-commit
  Cons/                                  local, ignorado
  ReplicatedStorage/Azazel/
    init.luau                            facade: { Version, Settings, WeaponConfig, EquipmentConfig, Strings }
    Version.luau                         Major/Minor/Patch/Channel/Build, ToString(), Tag()
    Config/
      Settings.luau                      Camera, Viewmodel, Keys, Hud, Server, Effects, Animations, Debug, Strings
      WeaponConfig.luau                  Defaults <- Classes[class] <- Weapons/<Name>; Get, All, Resolve(name, modifiers)
      Weapons/<Name>.luau                um por arma (Pistol, SMG, Rifle, Shotgun, Sniper no lote 1)
      EquipmentConfig.luau               Get, All, StackModifiers(list)
      Equipment/<Name>.luau              HelmetLight, VestLight...
      AnimationIds.luau                  manifesto [Class][Slot], Weapons[Name][Slot], R15[Class][Slot]
    Shared/
      Remotes.luau                       registro fechado: nome -> kind/direcao/schema T/rate; EnsureAll, OnServer, OnClient, Get
      Accuracy.luau                      puro: Step(state,cfg,now), Cone(cfg,state,ctx), Sample(dir,coneDeg,rng), PixelsFor
      Rig.luau                           abstracao do rig (R6 agora, tabela R15 stub): nomes de partes/juntas, HandOffset, ViewmodelKeep, ZoneOf(part), Detect(character)
      WeaponModel.luau                   Clone(cfg) | Placeholder(), Sanitize, Attach(rig, model, cfg) via Motor6D "Handle", Detach, FindAttachment
      Animations.luau                    slots (prioridade/loop), resolucao de id Studio x live, NewSet(class, weapon) -> Bind/Unbind/Play/Stop/Destroy, ReportMissing
      Spring.luau                        mola com impulso (Vector3) para sway/bob/recoil do viewmodel
      UIKit.luau                         New(className, props) com pseudo-props Corner/Stroke/Padding/ListLayout/GridLayout/Children; Theme; Screen(name)
    Packages/                            vendorados de Cons: Trove, Signal (EasySignal/Signal), Spr (_Spr), T, Shake, PartCache/, Observers/
    Assets/
      Manifest.luau                      lista esperada (Doctor); mantem a pasta no repo
      Weapons/<Model>  Animations/<Class>/<Slot>  Animations/Weapons/<Name>/<Slot>  Effects/  Sounds/   (a mao no Studio)
    Dev/
      Commands.luau                      so Studio: BuildAnimationRig, CollectAnimSaves, PrintGrip, ImportWeapon, ReportMissingAnimationIds, Doctor, Give, SpawnDummy
    Client/
      init.luau                          bus do client: Signals (WeaponChanged, AmmoChanged, SprayChanged, ViewChanged, AimChanged, StateChanged, LocalShot)
      Controllers/
        InputController.luau             ContextActionService <- Settings.Keys -> Signals do bus + IsDown()
        CameraController.luau            OTS, LockCenter, yaw/pitch, ombro, V, ADS FOV/distancia (Spr), colisao, recoil spring, Shake, GetAimRay()
        WeaponController.luau            estado previsto, loop de tiro (Auto/Semi/Burst), reload/equip, reconciliacao com State, AnimationSet, sons
        ViewmodelController.luau         clone do rig -> Camera, strip, Attach da arma, molas, RenderStep, ADS pelo Sight, esconde boneco
        EffectsController.luau           tracers (PartCache + Trail), cartuchos, muzzle flash, impactos, sons 3D de todos os atiradores
        HudController.luau               crosshair dinamico, municao, hotbar, hitmarker, scope overlay, armadura (UIKit)
  ServerScriptService/
    Azazel.server.luau                   bootstrap: Remotes.EnsureAll(); Start() ordenado em pcall; "[Azazel] vX N/M systems started"
  ServerStorage/Azazel/
    init.luau                            API server: SetLoadout, GiveWeapon, RemoveWeapon, GiveEquipment, GetState, Signals OnShot/OnHit/OnKill
    Systems/
      Inventory.luau                     loadout/slots/municao/equipamento/maquina de estado de equip; push de State; handshake Ready
      CharacterRig.luau                  no spawn: detecta rig, prende/solta o Model replicado (Motor6D), atributos do Character, limpeza na morte
      Combat.luau                        Fire/Reload/Aim/SetFireMode; validacao; spread no server; raycast; dano/zonas/armadura/falloff; kill credit; ShotFired/HitConfirmed
  StarterPlayer/StarterPlayerScripts/
    Azazel.local.luau                    bootstrap client: task.spawn+pcall por controller, sem ordem
```

Server em `ServerStorage/Azazel/` porque `ServerScriptService` nao pode ter Script e Folder com o
mesmo nome `Azazel`, e logica de server nao replica. Controllers em `ReplicatedStorage/Azazel/Client/`
(nada secreto ali) para o pacote ser uma pasta so + 2 bootstraps.

### Modelo de dados (resumo; shape completo vai no README)

`Config/Weapons/AK47.luau`: `Name, DisplayName, Class, Model, Grip (CFrame C1), FireModes, Rpm,
Burst{Count,Rpm}, Magazine, Reserve, Reload{Mode,Time,EmptyTime}, EquipTime, Range,
Damage{Base,FalloffStart,FalloffEnd,FalloffMultiplier,Zones{Head,Torso,Limb}},
Accuracy{Base,AimMultiplier,HipMultiplier,PerShot,Max,RecoveryDelay,RecoveryTime,Movement{...=1}},
Pellets{Count,Spread}, Recoil{Camera{Pitch,Yaw,Damping,Frequency},Viewmodel{Kick,Rise,Damping,Frequency}},
Ads{Fov,Distance,Shoulder,Time,AimTime,Scope,ScopeImage,SightDistance,ViewmodelOffset},
Effects{MuzzleFlash,Impact,Casing,Tracer{Enabled,Every,Speed,Length,Width,Color,Style}},
Sounds{Fire,Reload,ReloadEmpty,Equip,Empty,FireMode}, Animations{<Slot> = id}`.
`WeaponConfig.Get` faz deep merge Defaults <- Classes[Class] <- arma, congela, deriva `ShotInterval`.

`Config/Equipment/HelmetLight.luau`: `Name, DisplayName, Zone (Head|Torso), DamageMultiplier,
Durability{Max, LossPerHit}, Modifiers{MagazineSize{Add,Mul}, Accuracy{Mul}, RecoilCamera{Mul}, ...}`.
`StackModifiers` soma Add e multiplica Mul; `WeaponConfig.Resolve(name, modifiers)` aplica. Assim
capacete/colete v1 e municao/precisao futuras usam a mesma tabela.

### Modelo de precisao (CS-like)

Estado por jogador+arma: `{ Spray = 0, LastShotAt = 0, AimStartedAt }`.
- `Step`: `idle = now - LastShotAt - RecoveryDelay; if idle > 0 then Spray = max(0, Spray - (Max/RecoveryTime) * elapsed)`.
- `cone = Base * Movement[stance] * (aiming and AimMultiplier or HipMultiplier) + Spray` (graus).
  Primeira bala: `Spray == 0` -> `cone == Base` (Sniper ~0.02, MP5 ~0.6).
- Sorteio so no server: `theta = rad(cone)*sqrt(u1)`, `phi = 2*pi*u2`, rotaciona a direcao.
- Apos o tiro: `Spray = min(Spray + PerShot, Max)`, `LastShotAt = now`.
- Shotgun: N pellets, cada um `Sample(Sample(dir, cone), Pellets.Spread)`, raycast e dano por pellet.
- ADS so vale no server se `now - AimStartedAt >= Ads.AimTime`.
- Client roda o mesmo `Step`/`cone` so para o tamanho do crosshair. Recoil de camera e visual
  (mola com impulso) e separado do spread.

### Fluxo do tiro e remotes

| Remote | Dir | Payload | Rate/s |
|---|---|---|---|
| Ready | C->S | () | 2 |
| Equip | C->S | slot 0..5 | 8 |
| Reload | C->S | () | 6 |
| Aim | C->S | aiming: boolean | 10 |
| SetFireMode | C->S | index | 5 |
| Fire | C->S | origin: Vector3, direction: Vector3 (unit), seq: integer | ceil(maxRpm/60)+5 |
| State | S->dono | {Weapon, Slot, Slots, Ammo, Reserve, Magazine, FireMode, EquipState, Equipment} | - |
| ShotFired | S->todos (Unreliable) | shooter, weapon, ends: {Vector3}, hits: {Instance?} | - |
| HitConfirmed | S->atirador | zone, damage, killed | - |

Validacao no server, nesta ordem: schema T + rate (registro) -> Inventory existe, EquipState ==
Ready -> vivo -> `seq` crescente -> `now - LastShotAt >= interval*0.9` e janela de 1 s
`<= Rpm/60*1.15 + WindowSlack` -> Ammo > 0 -> `(origin - Head.Position).Magnitude <= 8` -> direcao
finita, unitaria, yaw <= 75 graus da frente do root, pitch <= 85. Falha: warn (se
`Debug.LogRejections`), manda `State` para ressincronizar, retorna. Raycast exclui o atirador
(partes de arma/tracer/cartucho com `CanQuery=false`). Dano = `Base * Zones[zone] * falloff`,
depois armadura da zona (multiplicador + durabilidade; quebrou -> remove e manda State para a
vitima), `TakeDamage`, credito de kill (`creator` ObjectValue + atributos no Humanoid). `State`
so em rejeicao/evento de ciclo de vida, nunca por tiro. HUD: Signals do bus (instantaneo) +
`StateChanged` (autoritativo sobrescreve). Sem Sincy: e um punhado de numeros e a Sincy espalha
remotes e dados para todos os clients.

### Viewmodel

- `character.Archivable = true; clone = character:Clone()`; mantem `HumanoidRootPart, Torso, Left
  Arm, Right Arm` + Shirt/BodyColors; destroi o resto (Head, pernas, Humanoid, Animate, acessorios,
  juntas Neck/Hip). Adiciona `AnimationController + Animator`. Partes: sem colisao/query/touch,
  Massless, CastShadow off; root ancorado e invisivel. Parent = `workspace.CurrentCamera`.
- Arma: `WeaponModel.Clone(cfg)` fresco de `Assets` + `WeaponModel.Attach` (mesma funcao que o
  server usa no boneco real, mesmo Motor6D `Handle`, `C0 = Rig.HandOffset`, `C1 = cfg.Grip`).
- Esconde o boneco real via `LocalTransparencyModifier = 1` (reaplica em DescendantAdded).
- RenderStep (apos a camera): `root.CFrame = hipCF:Lerp(sightCF, adsAlpha) * sway * bob * recoil`,
  com molas proprias (`Shared/Spring`) para sway/bob/recoil e `Spr` para FOV/distancia/adsAlpha.
  `sightCF` alinha o attachment `Sight` ao centro da tela; sem `Sight` usa `Ads.ViewmodelOffset`.
- `AnimationSet` do WeaponController faz `Bind` no Animator do boneco sempre e no do viewmodel em
  1a pessoa; `Play(slot)` toca em todos os Animators vinculados. V destroi/recria via Trove.

### Pipeline de animacao

- Slots (prioridade): Idle (Idle, loop), Aim/Sprint (Movement, loop), Fire (Action2), Reload/
  ReloadEmpty/Inspect (Action), Equip/Unequip (Action3). Reload/Equip usam `AdjustSpeed` para
  casar com o tempo do config.
- `ResolveId(class, slot, weapon)`: `cfg.Animations[slot]` -> `AnimationIds.Weapons[name][slot]`
  -> `AnimationIds[class][slot]`. No Studio, antes do manifesto, procura KeyframeSequence em
  `Assets/Animations/Weapons/<Name>/<Slot>` e `Assets/Animations/<Class>/<Slot>` e registra.
- Fluxo do Gabriel: `BuildAnimationRig("Rifle","AK47")` na Command Bar -> Animation Editor no rig
  (a arma aparece como junta) -> anima Idle/Fire/Reload/Equip -> Save (vai para `rig.AnimSaves`)
  -> `CollectAnimSaves()` move para `Assets/Animations/Rifle/<Slot>` -> Play ja toca -> quando for
  publicar: botao direito na KeyframeSequence > Save to Roblox -> cola o id em `AnimationIds.luau`
  -> `ReportMissingAnimationIds()` vazio.
- Orientacao no README: animar so `Right Arm`, `Left Arm`, `Handle` (e Torso se quiser); deixar
  root/cabeca/pernas sem keyframe para o Animate padrao continuar andando/pulando por baixo.

### Modulos vendorados (verificado: sem dependencias externas)

`Trove.luau`, `EasySignal/Signal.luau` -> `Signal.luau`, `BetterTweenService/_Spr.luau` ->
`Spr.luau`, `T.luau`, `Shake.luau`, `PartCache/` (init + `_Table`, ja usa `script._Table`),
`Observers/`. Nenhum tem require por string apos essa selecao. Cada arquivo ganha no topo uma
linha com origem e licenca. Nao vendorar: `Link` (bug `wireConnections` indefinido, remotes
parentados nele mesmo), `Sincy`, `Input` (ContextActionService cobre), `Timer`, `TableUtil`
(um `deepMerge` de 15 linhas basta), `Promise`, `Conch` (68 arquivos; um `Dev/Commands` so
Studio na Command Bar resolve).

### Versionamento e git

- `Version.luau`: `{ Major, Minor, Patch, Channel, Build }`, `ToString()` -> `0.1.0-alpha.1`,
  `Tag()` -> `v0.1.0-alpha.1`. Log de boot imprime a versao.
- Canais: `dev` (em construcao, pode nao rodar), `alpha` (roda no Studio, incompleto), `beta`
  (funcionalidade completa, em teste), `rc` (candidata), `release` (estavel), `hotfix` (correcao
  sobre release). `Build` sobe a cada commit no mesmo canal.
- Regra: **todo commit muda `Version.luau` e `CHANGELOG.md`**; tag `vX.Y.Z-canal.N` em cada
  commit. `.githooks/pre-commit` (sh) recusa commit sem mudanca em `Version.luau`; ativado com
  `git config core.hooksPath .githooks` (documentado no COMMITS.md).
- `COMMITS.md`: formato `tipo(escopo): resumo` em ingles (`feat`, `fix`, `feel`, `docs`, `chore`,
  `refactor`, `assets`), corpo curto dizendo o porque, rodape com a versao; texto humanizado e
  curto, com exemplos. `README.md`: instalacao (copiar `Azazel` + 2 bootstraps, R6 no Game
  Settings), configurar armas/equipamentos, API server (`GiveWeapon`, `SetLoadout`, Signals),
  API client (bus), pipeline de animacao, seguranca, versoes/canais.
- `.gitignore`: `Cons/`, `*.rbxl`, `*.rbxlx`, `*.rbxl.lock`, `sourcemap.json`, `.vscode/`.

## Seguranca (checklist)

Registro fechado de remotes (nome desconhecido erra no require); todo handler com schema T +
token bucket + contador de violacoes (`KickOnAbuse` opcional). Client so manda origem, direcao
unitaria e seq. Server e dono de RNG do spread, municao, timers, estado de equip, fire mode,
raycast, dano, armadura, kill. Sem RemoteFunction, sem HTTP, sem DataStore, sem segredo no repo.
`ImportWeapon` apaga todo `LuaSourceContainer` do free model; `Doctor` falha se houver script
em `Assets`. `Dev/Commands` retorna tabela vazia fora do Studio. Estado zerado em
PlayerRemoving/CharacterRemoving; toda conexao em Trove.

## Fases (cada uma testada em Play antes da proxima)

**Fase 1 — Esqueleto + hitscan sem animacao e sem viewmodel.**
Passo 0: copiar de `Cons\Cons\` os modulos vendorados para `ReplicatedStorage/Azazel/Packages/`
(pedido do Gabriel: "adicione a Cons agora"). `git init`, `.gitignore`, `Version 0.1.0-alpha.1`,
README/CHANGELOG/COMMITS, `.githooks`. `Remotes`, `Settings`, `WeaponConfig` +
`Weapons/DebugRifle.luau` (sem `Model` -> cubo placeholder com `Handle` e `Muzzle`), `Rig`,
`WeaponModel`, `Accuracy`, `Inventory/CharacterRig/Combat`, bootstraps, `Input/Camera
(OTS, lock, boneco gira)/Weapon (loop + predicao)/Effects (tracer fino que viaja)/Hud (municao +
crosshair)`. A mao: Game Settings > Avatar > R6. Commit + tag.
Verificar: cubo na mao direita; `Dev.Commands.SpawnDummy()`; tiro desconta municao, dummy leva
dano por zona, reload recarrega; payloads invalidos pela Command Bar do client (direcao nao
unitaria, origem longe, 200 RPM) -> warn e HUD ressincroniza; boot imprime `3/3 systems`.

**Fase 2 — Armas reais, equip, equipamento, comandos de animacao.**
`ImportWeapon`, `PrintGrip`, `BuildAnimationRig`, `CollectAnimSaves` (adiantados para o Gabriel
comecar a animar enquanto a fase 3 anda); 5 armas do lote 1 importadas do Weapons Kit da Roblox;
hotbar/equip/unequip com `EquipTime`; fire modes; `EquipmentConfig` + dano/durabilidade; HUD
completo; `Doctor`. A mao: inserir os modelos, rodar `ImportWeapon`, afinar Grip.
Verificar: trocar slot troca o Model no boneco (Motor6D visivel em Server view); capacete reduz
dano na cabeca e quebra em 0; `Doctor()` limpo.

**Fase 3 — Feel: precisao, recoil, ADS, efeitos.**
Spray CS + crosshair dinamico, recoil de camera, Spr para FOV/distancia, troca de ombro, colisao
da camera, pellets, scope da sniper, estilos de tracer/`Every`, cartuchos, muzzle flash,
impactos, sons, Shake. A mao: `Assets/Effects/*`, `Assets/Sounds/*`.
Verificar: primeira bala no ponto; segurar abre o crosshair e os impactos; soltar recupera em
`RecoveryTime`; shotgun manda 8 `ends`; FOV e overlay da sniper; tracer sai do cano ate o impacto.

**Fase 4 — Pipeline de animacao.**
`Animations`, `ReportMissingAnimationIds`, `WeaponController` tocando slots (Idle em loop no
equip, Fire por tiro, Reload/Equip cronometrados). A mao: animar Idle/Fire/Reload/Equip do Rifle.
Verificar: toca no Play por auto-registro; segundo client (Test com 2 jogadores) ve a animacao
do outro; `ReportMissingAnimationIds()` lista 4 ate colar os ids.

**Fase 5 — Viewmodel 1a pessoa.**
`ViewmodelController`, `Spring`, V, esconder boneco, ADS pelo `Sight`. A mao: attachments
`Sight` nas armas.
Verificar: V alterna; bracos do viewmodel tocam o mesmo Reload que o boneco em 3a pessoa (checar
no segundo client); ADS alinha o `Sight` ao centro; sem jitter andando.

**Fase 6 — Endurecimento + alpha.**
Ajuste de rate/abuso, testes de janela, secao de API no README, tabela R15 preenchida (nao
ativada), CHANGELOG, tag `v0.2.0-alpha.1`.

## Verificacao transversal

Play Solo e Test Server com 2 jogadores; Output com `[Azazel]`; Server/Client view para inspecionar
o Motor6D `Handle` e a pasta `Remotes`. Apos cada arquivo novo, confirmar no Explorer a classe
que o Script Sync criou. Seguranca pela Command Bar do client: 1000 tiros/s, direcao NaN,
origem em (0, 1e6, 0), `seq` repetido -> tudo rejeitado, so warns. Performance: MicroProfiler com
8 dummies atirando; tracers dentro de `TracerMaxLive`, PartCache sem expandir apos aquecer.

## Recomendacoes de modelos gratuitos (para o Gabriel)

- **Roblox Weapons Kit (endorsed, conta Roblox)**: Pistol, Shotgun, Auto Rifle, Submachine Gun,
  Sniper Rifle, Crossbow, Grenade Launcher, Rocket Launcher, Railgun. Estilo consistente, gratis,
  ja e Model no Studio (`ImportWeapon` apaga os scripts). Cobre o lote 1 inteiro.
  https://create.roblox.com/docs/resources/weapons-kit
- **Quaternius Ultimate Guns Pack** (CC0, 40+ armas, FBX/OBJ) via quaternius.com / itch.io /
  poly.pizza. Importar pelo 3D Importer do Studio.
- **Kenney.nl** (CC0, "Weapon Pack" / "Blaster Kit") e **Poly Pizza** (CC0, filtros por licenca).
- Regra de auditoria (do EB): recusar modelo com `require(<id>)`, `getfenv`, `loadstring`,
  `HttpService`, `PromptPurchase`; `ImportWeapon` apaga todo script de qualquer forma.

## Fora do escopo da v1 (registrado)

R15 (tabela stub), projetil com fisica (lancadores), lag compensation (v2: ring buffer de
posicoes), modificadores de movimento (existem no modelo com valor 1), mobile/gamepad (bindings
via ContextActionService ja preveem, UI de toque depois), Aim/Sprint/Inspect animados, sistema de
inventario/loja (o jogo que importa entrega loadout pela API server).

---

## Estado (atualizado em 13/09/2026)

**Fase 1 — feita e em teste no Play** (v0.1.0-alpha.1 a alpha.9). Tudo do escopo da fase
existe: pacotes vendorados, remotes fechados, config, Combat/Inventory/CharacterRig, camera
OTS, predicao, tracer, HUD, git, docs. Corrigido em Play: pasta Weapons, trail gigante,
cano solto do placeholder, tracer nascendo atras do cano.

**Extras que entraram fora do plano, por pedido do Gabriel** (ja feitos, nao repetir):

- Municao infinita por padrao (`Settings.Server.InfiniteAmmo`). Ver [Municao.md](Municao.md).
- Tracer grosso estilo Phantom Forces (0.2 x 5 studs). Ver [Tracados.md](Tracados.md).
- Modulo `Client/Quality` (Low/Medium/High pelo nivel grafico ou FPS) e efeitos que obedecem
  o nivel. Ver [Qualidade.md](Qualidade.md).
- Linhas de depuracao do servidor no Studio (`Settings.Debug.ServerTracers`). Ver
  [MelhoriasServer.md](MelhoriasServer.md).

**Regra de trabalho (13/09)**: pedido que saia do plano principal vai para um `.md` por
assunto nesta pasta e NAO e implementado na hora. O plano segue fase a fase; ao fechar o
plano, os `.md` viram a lista de refinamento.

**Fase 2 — escrita (v0.2.0-alpha.1), em teste no Play.** Equipamento (capacete/colete), 5 configs
do Weapons Kit no loadout padrao, hotbar e barras de armadura no HUD, comandos
`BuildAnimationRig`/`CollectAnimSaves`/`Doctor`/`Grip*`. O que o Gabriel faz a mao: inserir os
5 modelos do Weapons Kit e rodar `ImportWeapon` em cada um, afinar o Grip com `GripMove`/`GripRotate`
+ `PrintGrip` e colar no config, e comecar a animar com `BuildAnimationRig`.

**Fase 5 — escrita (v0.2.0-alpha.9), em teste no Play.** `ViewmodelController` + `Shared/Spring`:
clone do rig na camera, arma por Motor6D, sway/bob/recoil, ADS pelo `Sight` (fallback
`Ads.ViewmodelOffset`), V alterna, boneco escondido. Feita antes da Fase 3/4 a pedido do Gabriel
(sem animacoes para fazer no dia). Zoom pela roda em 3a pessoa (`MinDistance`/`MaxDistance`/
`ZoomStep`). O que o Gabriel faz a mao: attachment `Sight` nas armas.

**Ragdoll (v0.2.0-alpha.10)**, pedido do Gabriel fora do plano e feito direto: so morte por
arma Azazel; servidor desliga `BreakJointsOnDeath`, congela o boneco real e avisa todos os
clients pelo remote `Ragdoll`; cada client esconde o boneco e monta a propria copia
(`Shared/Ragdoll`, BallSocket por Motor6D, limites em `Settings.Ragdoll.Joints`), fisica
local, cap `RagdollMaxLive` por qualidade. Em teste no Play.

**Proxima**: resto da Fase 3 (scope, muzzle flash, impactos, cartuchos, Shake, sons), depois o
codigo da Fase 4 (Animations, slots) e a Fase 6.
