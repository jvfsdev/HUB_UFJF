# HUB-UFJF

Rede de apoio aos estudantes da UFJF. Trabalho prático da disciplina DCC117 – Modelagem de Sistemas (DCC/UFJF), desenvolvido com Scrum em 4 sprints. Os requisitos (RF01–RF15, RNF01–RNF15) e os diagramas UML estão no Documento de Requisitos do Software do HUB-UFJF.

- **App:** Flutter 3.47 / Dart (web agora; Android e iOS já configurados)
- **Backend:** Firebase (Auth, Cloud Firestore, Storage, Cloud Functions, Hosting), projeto `hub-ufjf`
- **Demo:** https://hub-ufjf.web.app

## Arquitetura

O sistema segue o padrão Cliente-Servidor em três camadas:

| Camada | Implementação |
|---|---|
| Apresentação | Flutter Web, em [app/](app/) |
| Processamento de aplicações | Security Rules ([firestore.rules](firestore.rules), [storage.rules](storage.rules)) e Cloud Functions ([functions/src/](functions/src/)) |
| Gerenciamento de dados | Cloud Firestore e Cloud Storage |

Dentro dos módulos, a comunicação segue o padrão BCE (Boundary-Control-Entity):
- **Boundary:** telas em `app/lib/features/*/presentation/`.
- **Control:** repositórios em `app/lib/features/*/data/`, Security Rules e Cloud Functions.
- **Entity:** modelos em `app/lib/models/` e as coleções do Firestore.

O modelo de dados segue o Diagrama de Classes:
- `publicacoes` concentra a hierarquia `Publicacao` (tópico, anúncio, evento, orientação) usando um campo `tipo`.
- `avaliacoes` mantém a associação polimórfica `tipoAlvo` + `alvoId`.
- `disciplinas.preRequisitos` implementa a autoassociação de pré-requisitos.

Os módulos do app correspondem aos seis módulos do escopo do sistema ([app/lib/features/](app/lib/features/)):

| Módulo | Pasta | Requisitos |
|---|---|---|
| Identidade e Acesso | `identidade/` | RF01, RF13 |
| Acadêmico | `academico/` | RF02, RF03 |
| Comunidade | `comunidade/` | RF04, RF05, RF14 |
| Conteúdos | `conteudos/` | RF08, RF10, RF11, RF15 |
| Anúncios e Divulgação | `divulgacao/` | RF06, RF09 |
| Moderação | `moderacao/` | RF07, RF12 |

Pontos de segurança:
- O perfil do usuário fica em uma *custom claim* (`role`). Só a function `completarCadastro` (ou o seed) pode defini-la, e as rules a usam para todo controle de acesso (RNF07).
- As avaliações não guardam o autor (RNF04). A regra "uma avaliação por item" é garantida por um HMAC irreversível de `uid + alvo`, cujo segredo fica no Secret Manager. A data da avaliação é guardada sem horário.
- Conteúdo publicado por usuários externos nasce `pendente`, e as rules impedem que seja visto antes da aprovação (RF07).

## Rodando localmente (Emulator Suite)

```bash
# 1. emuladores (Auth, Firestore, Storage, Functions)
npm --prefix functions install && npm --prefix functions run build
firebase emulators:start --only auth,firestore,storage,functions

# 2. dados de demonstração (outro terminal)
cd seed && npm install && npm run seed:emulador

# 3. app apontando para os emuladores
cd app && flutter run -d chrome --dart-define=USE_EMULATORS=true
```

O emulador precisa de `functions/.secret.local` com `AVALIACAO_HMAC_SECRET=<qualquer valor>`. Esse arquivo não vai para o git.

## Deploy em produção

```bash
cd app && flutter build web --release && cd ..
firebase deploy                      # hosting, functions, rules, índices e storage
gcloud auth application-default login   # uma vez, para o seed usar suas credenciais
cd seed && npm run seed:prod         # ATENÇÃO: --reset apaga e recria os dados
```

## Testes

| Suíte | Comando | Cobertura |
|---|---|---|
| Flutter | `cd app && flutter test` | lógica da grade (RF03), conflitos de permissão (RF13), guards do router (RNF07), validação de cadastro (RF01) |
| Functions | `cd functions && npm test` | parser do histórico com PDF (RF02), HMAC das avaliações (RF05), score de popularidade (RF10), keywords de busca (RF15) |
| Security Rules | `cd tests && npm test` (emuladores rodando) | 11 cenários de acesso por perfil, moderação, denúncias e uploads |
| Ponta a ponta | `cd tests && node --test e2e.test.mjs` (emuladores e seed) | avaliação anônima, importação de histórico, cadastro, moderação, denúncias e índices |
| Capturas de tela | `cd tests && node capturas.mjs <pasta> <conta> <rotas...>` | usa o build `app/build/web_emu` servido em `127.0.0.1:5050` |

## Contas de demonstração

A senha de todas é `HubUfjf@2026`. Também dá para entrar com os botões da tela de login.

| Conta | Perfil | Uso na demo |
|---|---|---|
| ana.estudante@estudante.ufjf.br | Estudante (ingressante de CC) | importa o histórico e avalia professores |
| bruno.veterano@estudante.ufjf.br | Estudante (6º período de CC integral) | histórico já importado, grade colorida, recomendações personalizadas |
| carla@prestador.com | Usuário Geral | anúncios de moradia; não pode avaliar |
| diego.vestibulando@gmail.com | Comunidade Externa | vê apenas Orientações; pergunta pendente de moderação |
| admin@hub-ufjf.dev | Administrador | aprovação, denúncias, permissões, logs |

## Roteiro da apresentação

1. **Bruno:** a Home mostra recomendações personalizadas (RF10). Na grade real de Ciência da Computação (65C), tocar em *Teoria dos Grafos* destaca a cadeia de pré-requisitos e o que ela libera (RF03). Buscar "Medicina" mostra um curso do catálogo sem grade cadastrada.
2. **Ana:** em *Importar histórico*, enviar `seed/assets/gerados/historico_demo_ana.pdf`. A function processa o arquivo e a grade aparece colorida (RF02).
3. **Ana:** em *Avaliações → Disciplinas*, avaliar *Sistemas Operacionais*. Na segunda tentativa, o sistema oferece editar a avaliação anterior (RF05).
4. **Ana:** criar um tópico em *Fóruns*. Ele aparece em tempo real numa segunda aba logada como Bruno (RF04, RNF03).
5. **Diego:** só enxerga *Orientações* (RF14). Uma nova pergunta dele fica *aguardando aprovação* (RF07).
6. **Admin:**
   - aprova a pergunta do Diego;
   - remove o tópico de spam denunciado (RF12);
   - em *Permissões*, marcar "Comunidade Externa → Fóruns" mostra o alerta de conflito (RF13);
   - em *Logs e índices*, recalcula os índices e o evento vencido é arquivado (RF09).
7. **Carla:** cadastra um anúncio com foto (RF06, RF11). Tentar enviar um `.exe` mostra a mensagem de formato não suportado.
8. **Qualquer conta:** em *Eventos*, uma data no passado é recusada (RF09). Em *Perfil*, há "Exportar meus dados" e "Excluir conta" (LGPD).

## Histórico escolar (RF02)

O parser em [functions/src/historico_parser.ts](functions/src/historico_parser.ts) segue o layout real do histórico emitido pelo SIGA/CDARA:

```
ANO SEM [CÓDIGO] NOME NOTA RESULTADO CH
```

- Nomes que quebram em várias linhas, páginas e resultados como `Rep Nota`, `Rep Freq` e `Matriculado` são tratados.
- Sufixos de turma especial são removidos (`MAT029E` vira `MAT029`).
- O curso é lido do PDF (ex.: `65B`), e a grade abre automaticamente nesse curso.

O PDF real usado na calibração contém dados pessoais. Por isso fica só em `seed/assets/historico_exemplo.pdf`, que está no `.gitignore`, e é testado apenas localmente. O teste versionado usa um texto fictício no mesmo layout.

## Dados reais da UFJF

Os dados acadêmicos vêm de um levantamento em páginas oficiais da UFJF, salvo em [seed/pesquisa/](seed/pesquisa/). Cada arquivo traz as URLs consultadas, a data de acesso e as lacunas encontradas.

| Arquivo | Conteúdo |
|---|---|
| `grade_cc.json` | Ciência da Computação: 65C integral (também 65AC, pelo BI em Ciências Exatas) e 35A noturno, currículos 2023 |
| `grade_si.json` | Sistemas de Informação (76A), currículo 2023 |
| `grade_ec.json` | Engenharia Computacional (65B), currículo 2023 |
| `cursos_ufjf.json` | Catálogo dos 89 cursos presenciais (JF e GV), unidades e ABIs |
| `docentes.json` | Departamentos e 117 docentes (nome, vínculo, áreas e turmas de 3/2026) |
| `projetos.json` | 36 grupos e projetos: GETs, PETs, empresas juniores, equipes de competição, laboratórios, extensão |
| `campus.json` | RU, circular, PROAE, serviços, calendário acadêmico, eventos e perguntas de ingresso |

- As grades trazem disciplinas obrigatórias por período, eletivas e pré-requisitos **por curso**: a mesma disciplina pode exigir coisas diferentes no integral e no noturno.
- Os demais cursos do catálogo aparecem na busca e no cadastro, sem grade.
- Professores reais **não** recebem avaliações semeadas; só a comunidade os avalia pelo app.
- Estudantes, prestadores, opiniões, tópicos e anúncios continuam fictícios. Os fatos citados neles (preços do RU, horários do circular, prazos, auxílios da PROAE) seguem as fontes oficiais.
