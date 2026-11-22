// Conteúdo da comunidade para a apresentação. Pessoas, contatos e opiniões são inventados; fatos sobre a UFJF
// (RU, circular, calendário, PROAE, PISM, eventos) seguem o levantamento em seed/pesquisa/campus.json.

export const SENHA_DEMO = 'HubUfjf@2026';

// [uid, nome, email, perfil, cursoId]
export const usuarios = [
  ['admin', 'Administração HUB-UFJF', 'admin@hub-ufjf.dev', 'admin', null],
  ['ana', 'Ana Clara Souza Martins', 'ana.estudante@estudante.ufjf.br', 'estudante', 'cc'],
  ['bruno', 'Bruno Henrique Teixeira', 'bruno.veterano@estudante.ufjf.br', 'estudante', 'cc'],
  ['carla', 'Carla Mendonça Ribeiro', 'carla@prestador.com', 'geral', null],
  ['diego', 'Diego Alves Pereira', 'diego.vestibulando@gmail.com', 'externo', null],
  // figurantes
  ['fernanda', 'Fernanda Lopes Cardoso', 'fernanda.lopes@estudante.ufjf.br', 'estudante', 'si'],
  ['gabriel', 'Gabriel Rocha Nunes', 'gabriel.rocha@estudante.ufjf.br', 'estudante', 'ec'],
  ['isabela', 'Isabela Martins Freitas', 'isabela.freitas@estudante.ufjf.br', 'estudante', 'cc'],
  ['joao', 'João Pedro Azevedo', 'joao.azevedo@estudante.ufjf.br', 'estudante', 'cc'],
  ['larissa', 'Larissa Gomes Pinto', 'larissa.pinto@estudante.ufjf.br', 'estudante', 'si'],
  ['mateus', 'Mateus Oliveira Campos', 'mateus.campos@estudante.ufjf.br', 'estudante', 'ec'],
  ['natalia', 'Natália Ferreira Rios', 'natalia.rios@estudante.ufjf.br', 'estudante', 'cc'],
  ['otavio', 'Otávio Machado Leal', 'otavio.leal@estudante.ufjf.br', 'estudante', 'si'],
  ['seuze', 'Seu Zé da Copiadora', 'copiadora.ze@prestador.com', 'geral', null],
  ['marta', 'Dona Marta (República Ipê)', 'republica.ipe@prestador.com', 'geral', null],
  ['erika', 'Érika Santos Lima', 'erika.vestibulanda@gmail.com', 'externo', null],
  ['vinicius', 'Vinícius Prado Moura', 'vinicius.moura@gmail.com', 'externo', null],
  ['promo', 'Renda Extra Já', 'renda.extra.ja@gmail.com', 'geral', null],
];

export const foruns = [
  ['circular', 'Circular e Transporte', 'Horários, rotas e lotação do circular interno e das linhas que vão ao campus.', 'bus', 0xff00796b],
  ['ru', 'Restaurante Universitário', 'Cardápio, filas, horários e avaliações das refeições do RU.', 'restaurant', 0xffef6c00],
  ['cursos', 'Cursos e Disciplinas', 'Dúvidas sobre matérias, matrícula, trancamento e grade.', 'school', 0xff0b3d91],
  ['resenhas', 'Resenhas e Dicas', 'Experiências, recomendações e dicas de veteranos para calouros.', 'reviews', 0xff6a1b9a],
  ['moradia', 'Moradia', 'Conversa sobre repúblicas, bairros, aluguel e convivência.', 'home', 0xff2e7d32],
  ['geral', 'Vida no Campus', 'Eventos, esportes, achados e perdidos e o que mais rolar na UFJF.', 'sports', 0xffc62828],
];

// Tópicos: { id, forum, autor, titulo, conteudo, dias (atrás), views, curtidas, respostas: [[autor, texto, horasDepois]] }
export const topicos = [
  {
    id: 't-circular-horarios', forum: 'circular', autor: 'bruno', dias: 40, views: 412, curtidas: 38,
    titulo: 'Guia definitivo dos horários do circular (2º semestre de 2026)',
    conteudo: `Pessoal, montei um resumo do quadro de horários do circular (é **gratuito**, ônibus cinza com letreiro "RU" ou "CIRCULAR"):

| Faixa | Letreiro | Frequência |
|---|---|---|
| 6h30 – 8h | RU | ~30 min |
| 8h – 11h | CIRCULAR | ~30 min |
| **11h – 14h** | RU | **~10 min** (4 ônibus) |
| 14h – 17h | CIRCULAR | ~30 min |
| 17h – 19h | RU | ~20 min |
| 19h – 22h | CIRCULAR | ~30 min |

A volta completa no anel viário leva de 35 a 55 min. O quadro oficial é uma previsão e muda sem aviso; ônibus "FUNCIONÁRIOS" são só para servidores. Se souberem de mudança, atualizem aqui!`,
    respostas: [
      ['isabela', 'Salvou demais! Confirmo que de manhã, com um ônibus só, chega cheio no ICE.', 3],
      ['gabriel', 'Na hora do almoço é tranquilo, passa um atrás do outro. O problema é das 8h às 11h.', 10],
      ['ana', 'Sou caloura e estava perdida com isso, muito obrigada! Pra ir do centro pro campus, qual linha?', 30],
      ['bruno', '@Ana as linhas 525 e 535 atendem o campus pela Zona Sul/Centro. Confere no site da prefeitura antes.', 32],
      ['joao', 'Dá pra fixar esse tópico? Todo semestre alguém pergunta a mesma coisa haha', 50],
    ],
  },
  {
    id: 't-circular-lotacao', forum: 'circular', autor: 'natalia', dias: 6, views: 96, curtidas: 7,
    titulo: 'Circular das 18h está pulando o ponto do ICB?',
    conteudo: 'Hoje e ontem o circular das 18h passou direto no ICB sem parar, alguém mais percebeu? Já mandei e-mail para a prefeitura do campus.',
    respostas: [
      ['larissa', 'Comigo aconteceu na terça. Acho que quando lota ele segue direto.', 2],
      ['otavio', 'Também mandei reclamação pelo Fala.BR, quanto mais gente mandar melhor.', 20],
    ],
  },
  {
    id: 't-ru-cardapio', forum: 'ru', autor: 'fernanda', dias: 2, views: 233, curtidas: 21,
    titulo: 'Cardápio do RU desta semana + fila ao vivo',
    conteudo: `Postando o cardápio da semana pra quem não acha no site:

| Dia | Almoço |
|---|---|
| Seg | Frango assado, arroz, feijão, salada de repolho |
| Ter | Estrogonofe de carne / opção vegana: grão-de-bico |
| Qua | Peixe empanado, purê |
| Qui | Feijoada (vegana disponível) |
| Sex | Macarrão à bolonhesa |

Quem passar pela fila, comenta aqui como está!`,
    respostas: [
      ['joao', '12h05 fila chegando na escada, uns 20 min.', 49],
      ['mateus', 'A feijoada de quinta é o melhor dia do RU, não percam.', 52],
      ['ana', 'Como paga o RU? Precisa de cartão?', 60],
      ['fernanda', '@Ana compra o ticket no caixa apresentando a carteirinha. Pra estudante é R$ 1,40 o almoço/jantar e R$ 0,50 o desjejum.', 61],
    ],
  },
  {
    id: 't-ru-horario', forum: 'ru', autor: 'ana', dias: 12, views: 61, curtidas: 4,
    titulo: 'Qual o melhor horário para evitar fila no RU?',
    conteudo: 'Tenho aula até 12h e às 13h de novo, sempre chego e a fila está enorme. Tem algum horário mais tranquilo?',
    respostas: [
      ['bruno', 'Depois das 13h15 costuma esvaziar bastante (o almoço vai até as 14h). Se não der, o jantar das 17h às 20h é bem mais tranquilo.', 1],
      ['isabela', 'Às 11h logo na abertura também é rápido!', 4],
      ['natalia', 'Se tiver aula no centro, o RU Centro (Rua Santo Antônio) serve almoço de segunda a sexta e a fila é menor.', 9],
    ],
  },
  {
    id: 't-calculo-dicas', forum: 'cursos', autor: 'bruno', dias: 25, views: 520, curtidas: 64,
    titulo: 'Como sobreviver a Cálculo I (de quem reprovou uma vez)',
    conteudo: `Reprovei Cálculo I no primeiro período e passei no segundo com folga. O que mudou:

1. **Fazer as listas toda semana**, não na véspera
2. Assistir às videoaulas *antes* da aula, não depois
3. Ir à monitoria (terças e quintas, 14h, sala 3 do ICE)
4. Estudar em grupo para a prova, explicando para os outros

Os materiais que usei estão na área de Materiais em MAT154. Força, calouros!`,
    respostas: [
      ['ana', 'Estou no 1º período e esse post me deu esperança 😅 vou começar pela monitoria.', 5],
      ['joao', 'A monitoria salva mesmo. E façam as provas antigas, os professores repetem muito o estilo.', 8],
      ['gabriel', 'Acrescento: o livro do Stewart tem exercícios resolvidos que ajudam muito.', 26],
      ['larissa', 'No noturno a monitoria é às 18h, pra quem é de SI.', 40],
      ['isabela', 'Salvei nos favoritos!', 70],
      ['natalia', 'O ponto 4 é o mais subestimado. Explicar pros outros é o melhor jeito de aprender.', 90],
    ],
  },
  {
    id: 't-trancamento', forum: 'cursos', autor: 'otavio', dias: 9, views: 88, curtidas: 5,
    titulo: 'Trancamento de disciplina conta no IRA?',
    conteudo: 'Estou pensando em trancar Estrutura de Dados porque peguei muitas matérias. Isso afeta o IRA ou o jubilamento?',
    respostas: [
      ['bruno', 'Trancamento não entra no cálculo do IRA, mas tem limite de trancamentos por curso. Vale conferir o regulamento acadêmico (RAG).', 3],
      ['fernanda', 'Eu tranquei uma em SI e não teve problema nenhum, só fique de olho no prazo: neste semestre o trancamento pelo SIGA foi até 25/09.', 10],
    ],
  },
  {
    id: 't-ed-prova', forum: 'cursos', autor: 'isabela', dias: 4, views: 140, curtidas: 12,
    titulo: 'Estrutura de Dados: o que cai na primeira prova?',
    conteudo: 'Alguém que já fez DCC013 sabe se a P1 cobra árvores ou só listas, pilhas e filas?',
    respostas: [
      ['bruno', 'Na minha turma foi listas encadeadas, pilha, fila e análise de complexidade. Árvores ficaram para a P2.', 2],
      ['joao', 'Treina implementar lista duplamente encadeada na mão, sempre cai.', 6],
      ['natalia', 'Coloquei uma prova antiga na área de materiais!', 20],
    ],
  },
  {
    id: 't-veterano-dicas', forum: 'resenhas', autor: 'natalia', dias: 33, views: 380, curtidas: 45,
    titulo: '10 coisas que eu queria saber no meu primeiro período',
    conteudo: `Compilando dicas da galera do 6º período:

1. A matrícula no SIGA é em **etapas**, não perca nenhuma
2. A Biblioteca Central fica no 2º andar da Reitoria e abre das 7h às 22h
3. Seu e-mail institucional é cpf@estudante.ufjf.br, com a mesma senha do SIGA
4. Procurem os GETs, empresas juniores e projetos de extensão cedo — o curso exige horas de extensão
5. Monitoria é de graça e subestimada
6. O Wi-Fi do campus é UFJF-WIFI, e o eduroam funciona com o login institucional
7. Assistência estudantil da PROAE é em fluxo contínuo pelo SIGA (renda até 1,5 salário mínimo per capita)
8. A PROAE tem atendimento psicológico para estudantes
9. A Semana da Computação acontece todo mês de outubro
10. **Use o HUB-UFJF** 😄`,
    respostas: [
      ['ana', 'Não sabia que a biblioteca abria até as 22h! Muito útil.', 12],
      ['gabriel', 'O 7 é muito importante, muita gente acha que tem edital com prazo e nem pede.', 30],
      ['larissa', 'Complementando o 4: em SI são 300h de extensão obrigatórias, comecem cedo.', 50],
    ],
  },
  {
    id: 't-resenha-ihc', forum: 'resenhas', autor: 'larissa', dias: 18, views: 74, curtidas: 9,
    titulo: 'Resenha: como é Interação Humano-Computador (DCC174)',
    conteudo: 'Fiz IHC no semestre passado (é obrigatória em SI e CC). Matéria leve na teoria, mas o trabalho prático (protótipo + teste com usuários) toma tempo. Ótima para quem quer ir para front-end ou produto.',
    respostas: [
      ['otavio', 'Concordo! O trabalho em grupo foi o melhor da graduação até agora.', 5],
      ['bruno', 'Estou fazendo agora, a parte de avaliação heurística é bem interessante.', 30],
    ],
  },
  {
    id: 't-bairros', forum: 'moradia', autor: 'ana', dias: 20, views: 210, curtidas: 15,
    titulo: 'Qual bairro é melhor para morar perto da UFJF?',
    conteudo: 'Vim de fora (sou de Barbacena) e estou procurando onde morar. Quais bairros vocês recomendam pensando em preço, segurança e acesso ao campus?',
    respostas: [
      ['bruno', 'São Pedro é o mais perto e tem muita república, mas o preço subiu. Dom Bosco é mais barato e dá pra ir a pé.', 2],
      ['marta', 'Temos vagas na República Ipê, no São Pedro, 8 minutos a pé do portão sul. Anunciei na área de anúncios!', 6],
      ['natalia', 'Cascatinha e Martelos têm ônibus direto, mas dependem do horário.', 24],
      ['gabriel', 'Moro no Dom Bosco há 2 anos, bem tranquilo, mercado perto.', 48],
    ],
  },
  {
    id: 't-convivencia', forum: 'moradia', autor: 'joao', dias: 14, views: 66, curtidas: 6,
    titulo: 'Dicas de convivência em república',
    conteudo: 'Primeira vez dividindo casa. Como vocês organizam limpeza e contas?',
    respostas: [
      ['isabela', 'Planilha compartilhada de contas e escala semanal de limpeza fixada na geladeira. Funciona!', 4],
      ['otavio', 'Combinem regras de visita logo no começo, evita muita briga.', 10],
    ],
  },
  {
    id: 't-futebol', forum: 'geral', autor: 'gabriel', dias: 7, views: 120, curtidas: 18,
    titulo: 'Futebol de quinta à noite na quadra da FAEFID',
    conteudo: 'Toda quinta às 19h tem pelada aberta na quadra da Educação Física. Qualquer curso, qualquer nível. Bora!',
    respostas: [
      ['joao', 'Tô dentro! Precisa levar bola?', 3],
      ['gabriel', 'Temos bola, só aparecer. Tragam água.', 4],
      ['mateus', 'Vôlei também rola no mesmo horário na quadra ao lado.', 20],
    ],
  },
  {
    id: 't-achados', forum: 'geral', autor: 'larissa', dias: 1, views: 35, curtidas: 2,
    titulo: 'Achei um guarda-chuva azul no RU',
    conteudo: 'Estava na mesa perto da janela, deixei na portaria do RU. Descreva o cabo para retirar.',
    respostas: [],
  },
  {
    id: 't-spam', forum: 'geral', autor: 'promo', dias: 1, views: 14, curtidas: 0,
    titulo: 'GANHE R$ 500 POR DIA TRABALHANDO DE CASA!!!',
    conteudo: 'Clique no link e descubra o método secreto para ganhar dinheiro fácil. Vagas limitadas!!!',
    respostas: [],
  },
];

// [id, autor, categoria, titulo, conteudo, contato, preco, bairro, dias, views, curtidas]
export const anuncios = [
  ['a-ipe', 'marta', 'republica', 'República Ipê: 2 vagas femininas no São Pedro',
    'Casa ampla com 5 quartos, 2 banheiros, internet de 300 Mb, máquina de lavar e quintal. Contas divididas (média de R$ 120). Ambiente tranquilo de estudo, a 8 minutos a pé do portão sul.',
    '(32) 99876-1234', 650, 'São Pedro', 15, 310, 22],
  ['a-dombosco', 'carla', 'republica', 'Quarto individual mobiliado no Dom Bosco',
    'Quarto com cama, guarda-roupa e escrivaninha em apartamento com mais 2 estudantes. Água e luz inclusas. Próximo ao ponto de ônibus e ao mercado.',
    'carla@prestador.com', 720, 'Dom Bosco', 8, 145, 9],
  ['a-masculina', 'otavio', 'republica', 'Vaga masculina na República Toca do Lobo',
    'Procuramos um morador para quarto compartilhado. Casa animada mas com respeito ao horário de estudo. Garagem para moto.',
    '(32) 98888-4321', 480, 'São Pedro', 5, 98, 4],
  ['a-cascatinha', 'carla', 'republica', 'Kitnet perto do campus (Cascatinha)',
    'Kitnet independente com cozinha americana e banheiro. Ideal para quem quer privacidade. Contrato semestral.',
    'carla@prestador.com', 900, 'Cascatinha', 22, 201, 11],
  ['a-mista', 'isabela', 'republica', 'República mista busca moradora/morador para 2027',
    'Abrindo vaga a partir de janeiro. Somos de CC, SI e Engenharia. Divisão de tarefas por escala e contas no app.',
    '(32) 99123-5566', 550, 'Martelos', 3, 54, 3],
  ['a-stewart', 'bruno', 'apostilas', 'Livro Cálculo Vol. 1 – Stewart (7ª edição)',
    'Em ótimo estado, poucas marcações a lápis. Ideal para Cálculo I e II.',
    '(32) 99555-7788', 120, 'Campus', 10, 167, 14],
  ['a-cormen', 'joao', 'apostilas', 'Algoritmos – Cormen (Teoria e Prática)',
    'Edição em português, capa um pouco gasta mas completo. Usei em Estrutura de Dados e PAA.',
    '(32) 98777-6655', 150, 'Campus', 12, 112, 8],
  ['a-apostila-fis', 'seuze', 'apostilas', 'Apostilas de Física I e II encadernadas',
    'Listas resolvidas pelos monitores, encadernadas na copiadora. Entrega no ICE.',
    '(32) 3215-0000', 25, 'Copiadora do ICE', 30, 89, 5],
  ['a-provas', 'seuze', 'apostilas', 'Coletânea de provas antigas de Cálculo (impressa)',
    'Material compilado com autorização dos monitores. Também temos versão digital gratuita na área de Materiais.',
    '(32) 3215-0000', 15, 'Copiadora do ICE', 18, 77, 6],
  ['a-jaleco-m', 'gabriel', 'jalecos', 'Jaleco branco tamanho M – usado 1 semestre',
    'Jaleco de algodão, manga longa, lavado e passado. Serve para laboratório de Química e Física.',
    '(32) 99999-1122', 40, 'Campus', 6, 58, 2],
  ['a-jaleco-g', 'larissa', 'jalecos', 'Dois jalecos tamanho G com bordado removível',
    'Vendo os dois juntos ou separados. Bordado do nome pode ser retirado.',
    '(32) 98444-3322', 35, 'Centro', 16, 41, 1],
  ['a-epi', 'mateus', 'jalecos', 'Kit EPI para laboratório (óculos + luvas + jaleco P)',
    'Kit completo para aulas práticas de Engenharia. Tudo em ótimo estado.',
    '(32) 98111-2233', 70, 'Campus', 9, 37, 2],
  ['a-calculadora', 'mateus', 'materiais', 'Calculadora científica Casio fx-991ES Plus',
    'Funcionando perfeitamente, permitida nas provas de Cálculo e Física.',
    '(32) 98111-2233', 80, 'Campus', 4, 133, 10],
  ['a-arduino', 'gabriel', 'materiais', 'Kit Arduino Uno + protoboard + sensores',
    'Usei em Circuitos Digitais e Sistemas Embarcados. Acompanha caixa organizadora.',
    '(32) 99999-1122', 160, 'Campus', 11, 92, 7],
  ['a-esquadros', 'natalia', 'materiais', 'Jogo de esquadros e compasso para Desenho Técnico',
    'Kit completo Trident, pouco usado.',
    '(32) 98666-0099', 45, 'São Mateus', 27, 29, 1],
  ['a-monitor', 'joao', 'materiais', 'Monitor 22" Full HD – ótimo para estudar',
    'Monitor LG com cabo HDMI. Motivo da venda: mudança.',
    '(32) 98777-6655', 380, 'São Pedro', 2, 66, 4],
];

// Anúncio pendente de usuário externo (RF07) — criado com status pendente.
export const anunciosPendentes = [
  ['a-pend-erika', 'erika', 'republica', 'Procuro república para 2027 (aprovada no PISM)',
    'Fui aprovada em Medicina e procuro vaga em república feminina perto do HU. Alguém indica?',
    'erika.vestibulanda@gmail.com', null, 'HU / Dom Bosco', 0],
];

// [id, autor, categoria, titulo, conteudo, quando, hora, local, projetoId?, status?]
// `quando`: data ISO (eventos reais da UFJF) ou dias a partir de hoje (negativo = passado) para os da comunidade.
export const eventos = [
  // Calendário oficial e eventos reais (fontes em seed/pesquisa/campus.json).
  ['e-pism-2027', 'admin', 'academico', 'Provas do PISM 2027 (Módulos I, II e III)',
    'As provas dos três módulos do PISM 2027 acontecem em 05 e 06/12/2026, em Juiz de Fora e nas demais cidades definidas em edital. O resultado final do Módulo III está previsto para 04/02/2027. Horários e locais: consulte o cartão de confirmação no site da COPESE (www2.ufjf.br/copese).',
    '2026-12-05', 8, 'Juiz de Fora e cidades de prova do edital', null],
  ['e-fim-2026-3', 'admin', 'academico', 'Último dia letivo do 2º semestre de 2026',
    'Encerramento do 2º/2026 segundo o calendário regular (Resolução Congrad nº 325). O lançamento de notas vai até 19/12 e o recesso letivo é de 24/12 a 03/01.',
    '2026-12-16', 18, 'Todos os campi', null],
  ['e-matricula-2027', 'admin', 'academico', 'Matrícula de veteranos para o 1º semestre de 2027',
    'Primeira etapa da matrícula no SIGA para o 1º/2027 (de 11 a 15/02). As demais etapas são em 18 a 20/02 e 25/02, conforme a Resolução Congrad nº 396.',
    '2027-02-11', 8, 'SIGA (on-line)', null],
  ['e-inicio-2027', 'admin', 'academico', 'Início das aulas do 1º semestre de 2027',
    'Primeiro dia letivo do 1º/2027 no calendário regular. O último dia para trancar disciplina no SIGA será 24/04/2027.',
    '2027-03-15', 7, 'Campus Juiz de Fora', null],
  ['e-semic-2026', 'admin', 'academico', 'XXXII Seminário de Iniciação Científica (SEMIC 2026)',
    'Etapa presencial do SEMIC, organizado pela PROPP, com abertura, oficinas e apresentações de trabalhos de iniciação científica (graduação e ensino médio).',
    '2026-11-05', 9, 'Campus Juiz de Fora', null, 'arquivado'],
  ['e-semana-comp', 'admin', 'extensao', 'XXVIII Semana da Computação do DCC/UFJF',
    'Tema: Computação em Nuvem. Palestras, minicursos e atividades dentro da Semana do ICE 2026, organizada pelo DCC com a Code Empresa Júnior.',
    '2026-10-19', 9, 'Instituto de Ciências Exatas (ICE)', 'semana-computacao', 'arquivado'],
  ['e-festival-colonial', 'admin', 'academico', '37º Festival Internacional de Música Colonial Brasileira e Música Antiga',
    'Programação gratuita da Pró-Reitoria de Cultura em espaços culturais de Juiz de Fora, como o Cine-Theatro Central.',
    '2026-07-24', 20, 'Cine-Theatro Central e outros espaços', null, 'arquivado'],
  // Encontros organizados por estudantes (conteúdo da comunidade, fictício).
  ['e-roda-calouros', 'natalia', 'roda_conversa', 'Roda de conversa: ansiedade no primeiro período',
    'Conversa aberta entre calouros e veteranos sobre adaptação, rotina de estudos e saúde mental. Para atendimento profissional, a PROAE oferece atendimento psicológico gratuito.',
    3, 17, 'Hall do ICE', null],
  ['e-estudo-calculo', 'bruno', 'grupo_interesse', 'Aulão colaborativo para a prova final de Cálculo I',
    'Veteranos resolvendo provas antigas de MAT154 em grupo antes do fim do semestre. Tragam dúvidas!',
    6, 14, 'Sala de estudos do ICE', null],
  ['e-pelada', 'gabriel', 'grupo_interesse', 'Pelada de encerramento do semestre',
    'Futebol aberto a todos os cursos para fechar o semestre. Levem água.',
    10, 18, 'Quadra da Faculdade de Educação Física', null],
  ['e-estudo-algoritmos', 'otavio', 'grupo_interesse', 'Maratona de estudos de Algoritmos (véspera da P3)',
    'Sessão de exercícios de vetores, matrizes e funções em C++ para a última prova de DCC199.',
    -1, 18, 'Laboratório de graduação do DCC', null, 'aprovado'],
];

// Orientações (RF14): [id, autor, titulo, conteudo, cursoInteresse, dias, status, respostas: [[autor, texto, horasDepois]]]
export const orientacoes = [
  ['o-cc-mercado', 'diego', 'Ciência da Computação ou Sistemas de Informação?',
    'Vou prestar o PISM este ano e estou em dúvida entre CC e SI. Qual a principal diferença no dia a dia e no mercado?',
    'cc', 10, 'aprovado', [
      ['bruno', 'CC tem mais matemática e teoria (cálculo, grafos, compiladores); SI foca mais em gestão e sistemas para empresas e é noturno. As duas empregam muito bem. Se você curte matemática, CC; se quer trabalhar de dia, SI.', 5],
      ['fernanda', 'Sou de SI e trabalho como estagiária desde o 3º período por ser noturno. Isso pesou muito na minha escolha!', 26],
    ]],
  ['o-pism', 'erika', 'Como funciona o PISM? Dá para entrar só com o ENEM?',
    'Estou no 3º ano e não fiz os módulos I e II do PISM. Ainda tenho chance de entrar na UFJF?',
    null, 6, 'aprovado', [
      ['natalia', 'Sim! As vagas são divididas meio a meio: 50% pelo PISM e 50% pelo SISU (ENEM). E dá para fazer os dois ao mesmo tempo.', 3],
      ['bruno', 'Só um detalhe: o PISM é seriado (módulos I, II e III, com pesos 2, 3 e 5, total de 1.300 pontos), então sem os dois primeiros módulos o caminho é o SISU mesmo.', 20],
    ]],
  ['o-moradia-calouro', 'vinicius', 'Vale a pena morar em república no primeiro ano?',
    'Sou de outra cidade e vou fazer Engenharia Computacional. Moradia estudantil ou república?',
    'ec', 4, 'aprovado', [
      ['gabriel', 'Morei em república desde o início e recomendo: você faz amigos de outros cursos e divide os custos. A Moradia Estudantil da UFJF tem 113 vagas e entra por edital da PROAE; quem não consegue vaga pode pedir o auxílio-moradia (R$ 420/mês).', 8],
    ]],
  ['o-matematica-base', 'diego', 'Preciso ser muito bom em matemática para fazer Engenharia Computacional?',
    'Gosto de programar, mas tenho dificuldade em matemática. Isso vai me atrapalhar muito?',
    'ec', 3, 'aprovado', []],
  ['o-bolsas', 'erika', 'Quais bolsas existem para quem precisa trabalhar?',
    'Minha família não tem condições de me manter em outra cidade. Que auxílios a UFJF oferece?',
    null, 2, 'aprovado', [
      ['fernanda', 'A PROAE atende quem tem renda familiar de até 1,5 salário mínimo por pessoa: bolsa PNAES (R$ 560/mês), auxílio-moradia (R$ 420), auxílio-transporte, alimentação no RU e auxílio-creche. O pedido é em fluxo contínuo, pelo formulário socioeconômico no SIGA, depois que a matrícula estiver ativa.', 6],
    ]],
  ['o-abi-exatas', 'erika', 'O que é a ABI de Ciências Exatas? Dá para entrar em Computação por ela?',
    'Vi no edital que algumas vagas de Computação e Engenharia Computacional vêm do "BI em Ciências Exatas". Como funciona?',
    'ec', 5, 'aprovado', [
      ['gabriel', 'Você entra no Bacharelado Interdisciplinar em Ciências Exatas e, depois do 3º semestre, escolhe o curso de 2º ciclo (Computação, Estatística, Física, Engenharias...). Em Engenharia Computacional são 40 vagas por ano: 20 declaradas e 20 vindas do BI.', 4],
      ['isabela', 'A disputa entre os alunos do BI é pela carga horária cumprida em obrigatórias até o 3º período, então capriche no começo.', 30],
    ]],
  ['o-estagio', 'vinicius', 'Quando dá para começar a estagiar em Computação?',
    'Queria saber a partir de qual período o pessoal costuma conseguir estágio.',
    'cc', 1, 'aprovado', []],
  // pendentes de moderação (RF07)
  ['o-pend-diego', 'diego', 'Alguém pode me mostrar o campus num sábado?',
    'Vou visitar Juiz de Fora no próximo sábado e queria conhecer o ICE e o RU com algum estudante.',
    'cc', 0, 'pendente', []],
  ['o-pend-vinicius', 'vinicius', 'Quanto custa, em média, viver em Juiz de Fora como estudante?',
    'Queria uma estimativa de gastos com moradia, alimentação e transporte.',
    null, 0, 'pendente', []],
];

// Materiais: [id, autor, disciplina, tipo, titulo, descricao, url|arquivoPdf, dias, views, downloads]
// Quando o 7º campo começa com "pdf:", o seed gera o PDF e o envia ao Storage.
export const materiais = [
  ['m-calc-lista1', 'bruno', 'MAT154', 'pdf', 'Lista 1 resolvida – Limites e continuidade', 'Resolução comentada da primeira lista.', 'pdf:lista_limites', 25, 340, 180],
  ['m-calc-prova1', 'natalia', 'MAT154', 'prova', 'Prova 1 de Cálculo I – 2025/1', 'Prova com gabarito ao final.', 'pdf:prova_calculo', 40, 512, 301],
  ['m-calc-khan', 'bruno', 'MAT154', 'link', 'Khan Academy – Cálculo diferencial', 'Curso gratuito com exercícios interativos.', 'https://pt.khanacademy.org/math/differential-calculus', 50, 210, 95],
  ['m-calc-video', 'joao', 'MAT154', 'video', 'Videoaulas de Cálculo I (YouTube)', 'Playlist de aulas sobre limites, derivadas e integrais.', 'https://www.youtube.com/results?search_query=c%C3%A1lculo+1+limites+aula', 30, 188, 120],
  ['m-calc2-resumo', 'isabela', 'MAT156', 'pdf', 'Resumo de técnicas de integração', 'Tabela com substituição, partes e frações parciais.', 'pdf:resumo_integracao', 12, 133, 70],
  ['m-ga-lista', 'gabriel', 'MAT155', 'pdf', 'Lista de exercícios – Vetores e retas', 'Exercícios selecionados com respostas.', 'pdf:lista_ga', 20, 97, 41],
  ['m-alg-feofiloff', 'bruno', 'DCC199', 'link', 'Projeto de Algoritmos em C (Paulo Feofiloff – IME/USP)', 'Material clássico e gratuito sobre algoritmos em C.', 'https://www.ime.usp.br/~pf/algoritmos/', 60, 402, 250],
  ['m-alg-prova', 'natalia', 'DCC199', 'prova', 'Prova 2 de Algoritmos – 2025/3', 'Questões de vetores, matrizes e funções.', 'pdf:prova_algoritmos', 15, 260, 140],
  ['m-alg-lista', 'joao', 'DCC199', 'pdf', 'Lista de exercícios de laços e funções', '30 exercícios em ordem de dificuldade.', 'pdf:lista_algoritmos', 35, 198, 90],
  ['m-alg2-recursao', 'isabela', 'DCC200', 'pdf', 'Resumo: recursividade e ordenação', 'Merge sort, quick sort e análise de complexidade.', 'pdf:resumo_recursao', 9, 87, 33],
  ['m-ed-visualgo', 'bruno', 'DCC013', 'link', 'VisuAlgo – visualização de estruturas de dados', 'Animações de listas, árvores, heaps e hash.', 'https://visualgo.net/pt', 28, 230, 110],
  ['m-ed-prova', 'natalia', 'DCC013', 'prova', 'Prova 1 de Estrutura de Dados – 2025/1', 'Listas, pilhas e filas.', 'pdf:prova_ed', 4, 154, 77],
  ['m-ed-cp', 'joao', 'DCC013', 'link', 'CP-Algorithms', 'Referência de algoritmos e estruturas de dados.', 'https://cp-algorithms.com/', 45, 120, 58],
  ['m-poo-padroes', 'larissa', 'DCC025', 'link', 'Refactoring Guru – Padrões de projeto', 'Catálogo ilustrado de padrões de projeto em português.', 'https://refactoring.guru/pt-br/design-patterns', 19, 176, 85],
  ['m-poo-lista', 'otavio', 'DCC025', 'pdf', 'Lista de exercícios de herança e polimorfismo', 'Exercícios em Java com casos de teste.', 'pdf:lista_poo', 11, 69, 30],
  ['m-grafos-resumo', 'bruno', 'DCC059', 'pdf', 'Resumo de Teoria dos Grafos', 'BFS, DFS, Dijkstra, Kruskal, Prim e fluxo.', 'pdf:resumo_grafos', 22, 214, 120],
  ['m-bd-sql', 'fernanda', 'DCC060', 'link', 'Tutorial interativo de SQL (W3Schools)', 'Pratique consultas direto no navegador.', 'https://www.w3schools.com/sql/', 16, 143, 66],
  ['m-bd-prova', 'larissa', 'DCC060', 'prova', 'Prova de Banco de Dados – normalização', 'Questões de 1FN a FNBC com resolução.', 'pdf:prova_bd', 7, 101, 45],
  ['m-es-req', 'bruno', 'DCC061', 'pdf', 'Modelo de documento de requisitos', 'Template usado no trabalho da disciplina.', 'pdf:modelo_requisitos', 13, 189, 99],
  ['m-es-mit', 'larissa', 'DCC061', 'link', 'Engenharia de Software Moderna (livro gratuito)', 'Livro online de Marco Tulio Valente.', 'https://engsoftmoderna.info/', 26, 245, 130],
  ['m-so-video', 'gabriel', 'DCC062', 'video', 'Aulas de Sistemas Operacionais (YouTube)', 'Processos, escalonamento e memória virtual.', 'https://www.youtube.com/results?search_query=sistemas+operacionais+escalonamento+aula', 21, 88, 40],
  ['m-redes-livro', 'mateus', 'DCC042', 'link', 'Computer Networks: A Systems Approach (livro aberto)', 'Livro gratuito e atualizado sobre redes.', 'https://book.systemsapproach.org/', 31, 74, 28],
  ['m-ia-curso', 'isabela', 'DCC014', 'link', 'Elements of AI – curso gratuito', 'Introdução à IA da Universidade de Helsinque.', 'https://www.elementsofai.com/', 17, 99, 47],
  ['m-est-lista', 'fernanda', 'EST028', 'pdf', 'Lista de probabilidade resolvida', 'Distribuições discretas e contínuas.', 'pdf:lista_estatistica', 24, 82, 39],
  ['m-fis-lista', 'mateus', 'FIS073', 'pdf', 'Lista de cinemática e dinâmica', 'Questões de provas anteriores.', 'pdf:lista_fisica', 29, 76, 31],
  ['m-python', 'larissa', 'DCC014', 'link', 'Tutorial oficial de Python (português)', 'Documentação oficial traduzida.', 'https://docs.python.org/pt-br/3/tutorial/', 8, 66, 25],
];

// Avaliações fictícias: comentários por alvo, sem autor (RF05/RNF04). Professores são reais e não recebem
// avaliações semeadas; só a comunidade os avalia pelo app.
export const comentariosAvaliacao = {
  disciplina: {
    DCC199: [[5, 'Base de tudo. Façam todas as listas.'], [4, ''], [4, 'Carga de trabalho alta no fim do período.'], [5, '']],
    DCC013: [[4, 'Difícil mas essencial para entrevistas de estágio.'], [5, ''], [3, 'Trabalhos práticos tomam muito tempo.']],
    DCC061: [[5, 'Aprende-se a trabalhar em equipe de verdade.'], [4, '']],
    DCC059: [[4, 'Conteúdo lindo, provas puxadas.'], [4, '']],
    MAT154: [[3, 'Precisa de dedicação desde a primeira semana.'], [2, 'Alto índice de reprovação.'], [3, ''], [4, 'Com monitoria fica tranquilo.']],
    MAT156: [[3, ''], [3, 'Séries são a parte mais difícil.']],
    DCC060: [[5, 'Muito útil no mercado.'], [4, '']],
    DCC062: [[3, 'Pesada, mas ensina muito sobre como o computador funciona.']],
    DCC025: [[5, 'Java e boas práticas, ótima disciplina.'], [4, '']],
    EST028: [[4, '']],
  },
  projeto: {
    getcomp: [[5, 'O Manual para Calouros e os aulões do GET me ajudaram muito no primeiro período.'], [5, '']],
    'code-jr': [[5, 'Experiência de projeto real com cliente ainda na graduação.'], [4, 'Exige bastante tempo, organize-se.']],
    'meninas-digitais-ufjf': [[5, 'Projeto lindo, levar computação para meninas das escolas faz diferença.'], [5, '']],
    rinobot: [[4, 'Aprende-se muito de eletrônica e programação embarcada.'], [5, '']],
    'semana-computacao': [[5, 'Minicursos ótimos e contato com empresas.'], [4, '']],
    labmaker: [[4, 'Espaço muito bom para prototipar.']],
    'cursinho-garra': [[5, 'Dar aula no cursinho mudou minha visão sobre a universidade.']],
  },
};

// Denúncias abertas (RF12): [denunciante, alvoPath, alvoTipo, alvoTitulo, motivo, detalhes, trecho]
export const denuncias = [
  ['joao', 'publicacoes/t-spam', 'topico', 'GANHE R$ 500 POR DIA TRABALHANDO DE CASA!!!', 'spam', 'Link suspeito, parece golpe.', 'Clique no link e descubra o método secreto para ganhar dinheiro fácil.'],
  ['larissa', 'publicacoes/t-spam', 'topico', 'GANHE R$ 500 POR DIA TRABALHANDO DE CASA!!!', 'falso', '', 'Clique no link e descubra o método secreto para ganhar dinheiro fácil.'],
  ['otavio', 'publicacoes/t-circular-lotacao/respostas/r-ofensiva', 'resposta', 'Resposta em "Circular das 18h está pulando o ponto do ICB?"', 'ofensivo', 'Xingamento ao motorista.', 'Esse motorista é um ****, deviam demitir.'],
  ['natalia', 'materiais/m-calc-prova1', 'material', 'Prova 1 de Cálculo I – 2025/1', 'direitos_autorais', 'Não sei se o professor autorizou a divulgação.', null],
];
