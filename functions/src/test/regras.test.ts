import { strict as assert } from "node:assert";
import { test } from "node:test";
import { calcularScore } from "../agendadas";
import { guardId } from "../avaliacoes";
import { gerarKeywords } from "../common";

test("guard de avaliação é determinístico e não revela o uid", () => {
  const a = guardId("segredo", "uid-ana", "professor", "p01");
  assert.equal(a, guardId("segredo", "uid-ana", "professor", "p01"));
  assert.notEqual(a, guardId("segredo", "uid-bruno", "professor", "p01"));
  assert.notEqual(a, guardId("outro-segredo", "uid-ana", "professor", "p01"));
  assert.ok(!a.includes("uid-ana"));
  assert.match(a, /^[0-9a-f]{64}$/);
});

test("score decai com o tempo e valoriza interações", () => {
  const agora = new Date("2026-10-27T12:00:00Z");
  const hoje = calcularScore(10, 2, agora, agora);
  const mesPassado = calcularScore(10, 2, new Date("2026-09-27T12:00:00Z"), agora);
  assert.equal(hoje, 16);
  assert.ok(mesPassado < hoje / 2);
  assert.ok(calcularScore(0, 5, agora, agora) > calcularScore(10, 0, agora, agora));
});

test("keywords incluem prefixos normalizados sem acento", () => {
  const k = gerarKeywords("Cálculo I – Prova", "república");
  assert.ok(k.includes("cal"));
  assert.ok(k.includes("calculo"));
  assert.ok(k.includes("republica"));
  assert.ok(!k.includes("i"));
});
