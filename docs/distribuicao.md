# Distribuição: assinatura Developer ID e notarização

Sem Developer ID o app é assinado só localmente (ad hoc). Funciona neste Mac, mas o macOS recusa as notificações e mostra o aviso de "desenvolvedor não identificado" em outros Macs. O `scripts/build-app.sh` já faz a parte técnica; os passos 1 a 3 dependem da conta do dono e só ele pode fazer (pagamento, termos, senha).

## Uma vez só

1. **Entrar no Apple Developer Program** em developer.apple.com/programs, com o Apple ID do dono (precisa de verificação em duas etapas). A anuidade e as condições estão nessa página; a aprovação pode levar de algumas horas a alguns dias.
2. **Criar o certificado "Developer ID Application"** (dá para fazer sem o Xcode):
   - Acesso às Chaves → menu Acesso às Chaves → Assistente de Certificado → Solicitar um Certificado de uma Autoridade de Certificação. Preencher o e-mail, escolher "Salvo no disco".
   - Em developer.apple.com/account/resources/certificates, botão "+", escolher **Developer ID Application**, enviar o arquivo `.certSigningRequest` e baixar o `.cer`.
   - Abrir o `.cer` com dois cliques; ele entra no Keychain junto com a chave privada criada no primeiro passo.
   - Conferir: `security find-identity -v -p codesigning` deve listar `Developer ID Application: <nome> (<TEAM ID>)`.
3. **Guardar as credenciais da notarização** no Keychain:
   - Criar uma senha de app em account.apple.com → Iniciar Sessão e Segurança → Senhas de Apps.
   - No Terminal (o comando pede a senha de app; ela fica só no Keychain, nunca no repositório):
     `xcrun notarytool store-credentials gitbeat-notary --apple-id <apple id> --team-id <TEAM ID>`

## A cada versão

- `scripts/build-app.sh --notarize --install`: compila, assina com o certificado encontrado, envia para a notarização, grampeia o ticket, confere com `spctl` e instala. Também gera `build/GitBeat.zip`, o arquivo para distribuir.
- Para usar outro certificado ou outro perfil: variáveis `GITBEAT_SIGN_ID` e `GITBEAT_NOTARY_PROFILE`.
- Se a notarização recusar, o histórico mostra o motivo: `xcrun notarytool log <id do envio> --keychain-profile gitbeat-notary`.

## Depois da primeira versão assinada

- Abrir o app, ligar as notificações nos Ajustes e conferir com `/Applications/GitBeat.app/Contents/MacOS/GitBeat --integration-status`. Se continuar `blocked`, a hipótese do Developer ID (`docs/decisoes.md`) estava errada e é preciso investigar outra causa.
- Atualizar a seção "Não verificado" do `AGENTS.md`.
