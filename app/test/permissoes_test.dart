import 'package:flutter_test/flutter_test.dart';
import 'package:hub_ufjf/core/router.dart';
import 'package:hub_ufjf/features/identidade/data/identidade_repository.dart';
import 'package:hub_ufjf/models/permissoes.dart';
import 'package:hub_ufjf/models/usuario.dart';

SessaoAtiva sessao(Perfil p, [Permissoes? perm]) => SessaoAtiva(
  Usuario(uid: 'u', nome: 'Teste', email: 't@x.com', perfil: p),
  perm ?? Permissoes.padrao,
  emailVerificado: true,
);

void main() {
  test('matriz padrão não tem conflitos', () {
    expect(Permissoes.padrao.conflitos(), isEmpty);
  });

  test('detecta conflitos da matriz (RF13 FA1)', () {
    final externoNosForuns = Permissoes.padrao.alternar(
      Perfil.externo,
      Area.foruns,
      Acao.ler,
    );
    expect(externoNosForuns.conflitos().single, contains('Comunidade Externa'));

    final geralAvalia = Permissoes.padrao.alternar(
      Perfil.geral,
      Area.avaliacoes,
      Acao.publicar,
    );
    expect(geralAvalia.conflitos().single, contains('Apenas Estudantes'));

    final publicaSemLer = Permissoes.padrao.alternar(
      Perfil.estudante,
      Area.foruns,
      Acao.ler,
    );
    expect(publicaSemLer.conflitos().single, contains('sem poder ler'));
  });

  test('serialização ida e volta preserva a matriz', () {
    final p = Permissoes.padrao.alternar(Perfil.geral, Area.grade, Acao.ler);
    expect(Permissoes.fromMap(p.toMap()).igual(p), isTrue);
    expect(p.igual(Permissoes.padrao), isFalse);
  });

  test('router aplica as permissões por perfil (RNF07)', () {
    expect(
      redirecionar(const SessaoDeslogada(), Uri.parse('/foruns')),
      '/login',
    );
    expect(
      redirecionar(sessao(Perfil.externo), Uri.parse('/foruns')),
      '/orientacoes',
    );
    expect(
      redirecionar(sessao(Perfil.externo), Uri.parse('/home')),
      '/orientacoes',
    );
    expect(
      redirecionar(sessao(Perfil.externo), Uri.parse('/orientacoes/nova')),
      isNull,
    );
    expect(
      redirecionar(sessao(Perfil.geral), Uri.parse('/orientacoes')),
      '/home',
    );
    expect(
      redirecionar(sessao(Perfil.geral), Uri.parse('/admin/moderacao')),
      '/home',
    );
    expect(
      redirecionar(sessao(Perfil.admin), Uri.parse('/admin/moderacao')),
      isNull,
    );
    expect(
      redirecionar(sessao(Perfil.estudante), Uri.parse('/login')),
      '/home',
    );
  });

  test('mudança de permissão vale imediatamente no router (RF13)', () {
    final semAnuncios = Permissoes.padrao.alternar(
      Perfil.geral,
      Area.anuncios,
      Acao.publicar,
    );
    expect(
      redirecionar(sessao(Perfil.geral), Uri.parse('/anuncios/novo')),
      isNull,
    );
    expect(
      redirecionar(
        sessao(Perfil.geral, semAnuncios),
        Uri.parse('/anuncios/novo'),
      ),
      '/home',
    );
    expect(
      redirecionar(sessao(Perfil.geral, semAnuncios), Uri.parse('/anuncios')),
      isNull,
    );
  });

  test('validação do cadastro (RF01 FA2)', () {
    final erros = IdentidadeRepository.validarCadastro(
      nome: 'A',
      email: 'ana@gmail.com',
      senha: '123',
      perfil: Perfil.estudante,
      consentimento: false,
    );
    expect(erros, hasLength(4));
    expect(
      IdentidadeRepository.validarCadastro(
        nome: 'Ana Souza',
        email: 'ana@estudante.ufjf.br',
        senha: '12345678',
        perfil: Perfil.estudante,
        consentimento: true,
      ),
      isEmpty,
    );
  });
}
