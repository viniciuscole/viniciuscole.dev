// GL/freeglut_std.h e GL/gl.h declaram glRasterPos2f, glutBitmapCharacter e
// glutBitmapHelvetica18, mas o Emscripten (verificado na tag fixada no
// Dockerfile) nunca implementou nenhuma das tres -- e um buraco conhecido e
// antigo da emulacao de GLUT dele, nao uma regressao deste projeto. Sem este
// shim o link falha com "undefined symbol" antes mesmo de chegar ao
// navegador.
//
// O jogo so usa essas tres chamadas para desenhar o placar em texto bitmap
// (ver main.cpp). Um no-op e suficiente para o link fechar e o jogo rodar;
// o unico efeito colateral e o placar em texto nao aparecer na tela --
// nao afeta fisica, colisao ou o restante do render em OpenGL.
mergeInto(LibraryManager.library, {
  glRasterPos2f: function (x, y) {},
  glutBitmapCharacter: function (font, character) {},
  glutBitmapHelvetica18: function () {},
});
