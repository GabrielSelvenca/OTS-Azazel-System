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
| Slots v1 | Relaxed, Idle, Aim, Reload (sem Fire, Gabriel 15/09; codigo preve tambem ReloadEmpty, Equip, Sprint, Inspect, Unequip; slot ausente e ignorado). |
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
      WeaponConfig.luau                  Defaults <- Classes[class] <- Weapons[Name]; Get, All, Resolve(name, modifiers)
      Weapons.luau                       todas as armas em um modulo so, uma entrada por nome (alpha.24)
      EquipmentConfig.luau               Get, All, StackModifiers(list)
      Equipment/<Name>.luau              HelmetLight, VestLight...
      AnimationIds.luau                  manifesto [Class][Slot], Weapons[Name][Slot], R15[Class][Slot]
    Shared/
      Remotes.luau                       registro fechado: nome -> kind/direcao/schema T/rate; EnsureAll, OnServer, OnClient, Get
      Accuracy.luau                      puro: Step(state,cfg,now), Cone(cfg,state,ctx), Sample(dir,coneDeg,rng), PixelsFor
      Rig.luau                           abstracao do rig (R6 agora, tabela R15 stub): nomes de partes/juntas, HandOffset, ViewmodelKeep, ZoneOf(part), Detect(character)
      WeaponModel.luau                   Clone(cfg) | Placeholder(), Sanitize, Attach(rig, model, cfg) via Motor6D "Handle", Detach, FindAttachment
      Animations.luau                    slots (prioridade/loop pelo Manifest), resolucao de id Studio x live, NewSet(class, weapon) -> Bind/Unbind/Play/Stop/Destroy
      Spring.luau                        mola com impulso (Vector3) para sway/bob/recoil do viewmodel
      UIKit.luau                         New(className, props) com pseudo-props Corner/Stroke/Padding/ListLayout/GridLayout/Children; Theme; Screen(name)
    Packages/                            vendorados de Cons: Trove, Signal (EasySignal/Signal), Spr (_Spr), T, Shake, PartCache/, Observers/
    Assets/
      Manifest.luau                      slots de animacao (nomes, prioridade, loop); mantem a pasta no repo
      Weapons/<Model>  Animations/<Class>/<Slot>  Animations/Weapons/<Name>/<Slot>  Reload/<Class>  Reload/Weapons/<Name>  Effects/  Sounds/   (a mao no Studio)
    Client/
      ShotDebug.luau                     linhas e prints de tiro no client (Settings.Debug.ClientShots, so Studio)
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

Entrada `AK47` em `Config/Weapons.luau`: `DisplayName, Class, Model, FireModes, Rpm,
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
  server usa no boneco real; as juntas vem dentro do modelo, `Attach` so preenche `Part0`).
- Do boneco real esconde so cabeca, bracos, acessorios deles e a arma (`LocalTransparencyModifier`,
  `Rig.FirstPersonHidden`, reaplica em DescendantAdded); torso e pernas ficam visiveis
  (`Settings.Viewmodel.ShowBody`, alpha.24). No clone so os bracos aparecem.
- RenderStep (apos a camera): `root.CFrame = hipCF:Lerp(sightCF, adsAlpha) * sway * bob * recoil`,
  com molas proprias (`Shared/Spring`) para sway/bob/recoil e `Spr` para FOV/distancia/adsAlpha.
  `sightCF` alinha o attachment `Sight` ao centro da tela; sem `Sight` usa `Ads.ViewmodelOffset`.
- `AnimationSet` do WeaponController faz `Bind` no Animator do boneco sempre e no do viewmodel em
  1a pessoa; `Play(slot)` toca em todos os Animators vinculados. V destroi/recria via Trove.

### Pipeline de animacao

- Slots (prioridade): Relaxed/Idle (Idle, loop), Aim/Sprint (Movement, loop), Reload/
  ReloadEmpty/Inspect (Action), Equip/Unequip (Action3). Sem slot Fire (Gabriel, 15/09): o tiro
  e kick de camera, mola do viewmodel e efeitos. Reload/Equip usam `AdjustSpeed` para
  casar com o tempo do config.
- `ResolveId(class, slot, weapon)`: `cfg.Animations[slot]` -> `AnimationIds.Weapons[name][slot]`
  -> `AnimationIds[class][slot]`. No Studio, antes do manifesto, procura KeyframeSequence em
  `Assets/Animations/Weapons/<Name>/<Slot>` e `Assets/Animations/<Class>/<Slot>` e registra.
- Fluxo do Gabriel: rig proprio com os nomes do jogo -> Moon Animator ou Animation Editor ->
  anima Relaxed/Idle/Aim/Reload -> exporta KeyframeSequence -> renomeia pelo slot e coloca a mao
  em `Assets/Animations/Rifle/` -> Play ja toca -> quando for publicar: botao direito na
  KeyframeSequence > Save to Roblox -> cola o id em `AnimationIds.luau`.
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
entrada `DebugRifle` em `Config/Weapons.luau` (sem `Model` -> cubo placeholder com `Handle` e `Muzzle`), `Rig`,
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
`Animations`, `WeaponController` tocando slots (Relaxed/Idle em loop, Aim segurando o botao,
Reload cronometrado; sem Fire); prioridade e loop pelo nome do slot no Manifest, porque as
KeyframeSequences entram a mao. A mao: animar Relaxed/Idle/Aim/Reload do Rifle (Relaxed, Idle e
Aim prontos em 15/09).
Verificar: toca no Play por auto-registro; segundo client (Test com 2 jogadores) ve a animacao
do outro.

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
- Corpo em 1a pessoa (alpha.24): torso e pernas reais visiveis, so cabeca, bracos e arma
  escondidos (`Settings.Viewmodel.ShowBody`).
- Armas em um modulo so, `Config/Weapons.luau` (alpha.24). Sem slot `Fire` (Gabriel, 15/09).
  Mira e `Sight` em [Miras.md](Miras.md); animacao em [Animacoes.md](Animacoes.md).
- Sem comandos de Studio (alpha.24): pasta `Dev/` apagada por regra do Gabriel; tudo em
  `Assets` entra a mao. `Client/ShotDebug` ficou porque e config, nao comando.
- Juntas dentro do modelo (alpha.24, 16/09): o modelo duplicado do rig traz os Motor6D
  (`Handle` <- braco direito, `Magazine` <- `Handle`) com `C0`/`C1`; `Attach` so preenche
  `Part0` pelo nome da parte que o motor ainda aponta, pelo nome do motor ou por
  `Rig.WeaponJoints`. `Grip` saiu do config. (O kit de pentes em `Assets/Reload/<Classe>`
  que entrou aqui foi apagado na alpha.25, a pedido do Gabriel.) Ver
  [Animacoes.md](Animacoes.md).

**Regra de trabalho (13/09)**: pedido que saia do plano principal vai para um `.md` por
assunto nesta pasta e NAO e implementado na hora. O plano segue fase a fase; ao fechar o
plano, os `.md` viram a lista de refinamento.

**Regra (15/09)**: nenhum comando de Studio, importador ou scaffolding no pacote. Nada cria,
importa ou edita instancia; o Gabriel monta modelo, attachments, juntas, KeyframeSequences e
sons a mao e o codigo so le. Quando uma feature precisar de asset, documentar o formato no
README e deixar o loader tolerante.

**Fase 2 — escrita (v0.2.0-alpha.1), em teste no Play.** Equipamento (capacete/colete), 5 configs
do Weapons Kit no loadout padrao, hotbar e barras de armadura no HUD, comandos
`BuildAnimationRig`/`CollectAnimSaves`/`Doctor`/`Grip*`. O que o Gabriel faz a mao: inserir os
5 modelos do Weapons Kit e rodar `ImportWeapon` em cada um, afinar o Grip com `GripMove`/`GripRotate`
+ `PrintGrip` e colar no config, e comecar a animar com `BuildAnimationRig`.
Import reforcado (alpha.13): `Dev/WeaponImport` converte marcadores em attachments, da Motor6D
a `Magazine`/`Bolt`/... (pivo no `<Nome>Attachment`, convencao Viethin), move sons para
`Assets/Sounds/<Arma>/` e descarta o resto; `{ Scale, Material }` opcionais. Fontes de modelo
escolhidas: Viethin 1.8 (Extension Packs publicos, so para o jogo) e Quaternius (CC0, pode ir
dentro do pacote; pente separado no Blender com `L` + `P`, cores por vertex color bake).
Backpack (alpha.19), adiantado a pedido do Gabriel: `Systems/Backpack` faz da Tool comum a fonte
do inventario (ver [Inventario.md](Inventario.md)); spawn sem loadout, configs do Weapons Kit
removidos, cinco armas Viethin no lugar. Comandos `Dev/*` apagados na alpha.24 (regra do
Gabriel, 15/09).

**Fase 5 — escrita (v0.2.0-alpha.9), em teste no Play.** `ViewmodelController` + `Shared/Spring`:
clone do rig na camera, arma por Motor6D, sway/bob/recoil, ADS pelo `Sight` (fallback
`Ads.ViewmodelOffset`), V alterna, boneco escondido. Feita antes da Fase 3/4 a pedido do Gabriel
(sem animacoes para fazer no dia). Zoom pela roda em 3a pessoa (`MinDistance`/`MaxDistance`/
`ZoomStep`). O que o Gabriel faz a mao: attachment `Sight` nas armas.
Pose de descanso (alpha.12): sem animacao os bracos do clone ficavam caidos e nada aparecia
na tela; `WeaponConfig.Defaults.Pose` (graus por braco) e aplicada nos ombros do viewmodel em
`PreSimulation` enquanto nenhuma track toca. O `Idle` da Fase 4 substitui a pose sozinho. Em
3a pessoa o boneco real continua com o braco caido ate a Fase 4 (animacao replicada).

**Ragdoll (v0.2.0-alpha.10)**, pedido do Gabriel fora do plano e feito direto: so morte por
arma Azazel; servidor desliga `BreakJointsOnDeath`, congela o boneco real e avisa todos os
clients pelo remote `Ragdoll`; cada client esconde o boneco e monta a propria copia
(`Shared/Ragdoll`, BallSocket por Motor6D, limites em `Settings.Ragdoll.Joints`), fisica
local, cap `RagdollMaxLive` por qualidade. Em teste no Play.

**Fase 4 — escrita (v0.2.0-alpha.25), em teste no Play.** `Shared/Animations`: um set por arma
equipada, ligado ao Animator do boneco e, em 1a pessoa, ao do viewmodel (o mesmo clip nos dois).
Slot em loop no Manifest e stance e troca a que estiver tocando (`Relaxed`, `Idle`, `Aim`,
`Sprint`); o resto e acao por cima (`Reload`, `ReloadEmpty`, `Equip`), com `AdjustSpeed` para
terminar junto com o timer do config. Prioridade e loop vem do nome do slot, slot ausente e
ignorado (os bracos voltam para a `Pose`), e no Studio as KeyframeSequences de
`Assets/Animations` sao registradas na hora. Maquina de estados como decidido em
[Animacoes.md](Animacoes.md): equipar cai em `Relaxed`, `Keys.Ready` (F) pede `Ready` e volta,
`Combat` so aceita tiro e mira em `Ready`, reload vale nos dois e devolve ao mesmo estado;
remote `Relax`, API `Azazel.SetRelaxed`. Sem pentes extras: o reload e um clip so, nos bracos e
nas partes da propria arma (decisao do Gabriel em 16/09, ver [Animacoes.md](Animacoes.md)). Com Backpack ligado, a
track de ferramenta do `Animate` e parada enquanto uma stance toca.
O que o Gabriel faz a mao: `Assets/Animations/Rifle/{Relaxed,Idle,Aim,Reload}`.
Bracos so pelo clip (17/09, alpha.26): sairam `Settings.Viewmodel.Offset`, a `Pose` de
descanso (`WeaponConfig.Defaults.Pose`, `Rig.PoseJoints`), `Ads.SightDistance` e
`Ads.ViewmodelOffset`. O clone fica no lugar exato do corpo real e, ao mirar, a camera vai ate
o ponto do `Sight` (`Client.SightOffset`); sem `Sight` fica na cabeca. `ShowBody` desligado por
padrao (torso e pernas reais somem) e o clone desenha so os bracos. Ver [Miras.md](Miras.md).
Pedidos do Gabriel em 17/09 (alpha.27): o clip e o timer do reload (`Animations.ClipLength`,
sem `MatchConfigTime`/`EquipTime`); `Sight`/`Muzzle` valem como Part ou Attachment; HUD sem
texto no meio da tela, `Reloading...` no lugar da municao; tiro com pente vazio recarrega;
camera do pacote so armado (`Relaxed` = camera e movimento da Roblox); ombros e pescoco seguem
o pitch da camera em 3a pessoa, replicado (`LookController`, remotes `Look`/`LookUpdate`).
Proximo pedido dele: responsividade e controles/botoes para mobile, em [Mobile.md](Mobile.md).
Sons (alpha.28): `SoundController` toca `Fire` por arma, `ModeSelect` na troca de modo e
`RemoveMag` + `InsertMag` em sequencia no reload; ver [Sons.md](Sons.md).

**Proxima**: teste no Play das animacoes do FN FNC (1a e 3a pessoa, depois Test com 2
jogadores), resto da Fase 3 (scope, muzzle flash, impactos, cartuchos, Shake, sons) e a Fase 6.
