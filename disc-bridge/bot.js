// Em producao o .env nao existe dentro da imagem (ver .dockerignore): as variaveis
// chegam pelo Compose. Aqui o dotenv nao acha arquivo e nao faz nada.
// No PC, rodando "node bot.js" direto, ele le o .env local. Fonte unica nos dois casos.
require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');
const { Telegraf } = require('telegraf');
const axios = require('axios');

const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

// =================== LOG ======================
// Timestamp em toda linha: sem isso nao da para correlacionar log com deploy.
function log(nivel, mensagem, extra = '') {
    console.log(`[${new Date().toISOString()}] [${nivel}] ${mensagem}`, extra);
}

log('BOOT', 'Gateway subindo...');

// Falha cedo e alto. Sem isso, variavel faltando vira bot mudo -- o pior modo de quebrar.
for (const nome of ['DISCORD_TOKEN', 'TELEGRAM_TOKEN', 'N8N_WEBHOOK_URL']) {
    if (!process.env[nome]) {
        log('FATAL', `Variavel ${nome} ausente. Abortando.`);
        process.exit(1);
    }
}
// So o host, nunca o caminho: a URL completa do webhook e' credencial (quem tem, escreve).
log('BOOT', `Variaveis OK. Webhook alvo: ${new URL(N8N_WEBHOOK_URL).host}/***`);

// =================== CONEXAO DISCORD ======================
const discordClient = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent
    ]
});

discordClient.on('messageCreate', async (message) => {
    if (message.author.bot) return;

    await enviarParaN8N(criarPayload({
        origem: 'discord',
        tipo: 'texto',
        timestamp: message.createdTimestamp,
        idCanal: message.channel.id,
        idUsuario: message.author.id,
        nomeUsuario: message.author.username,
        texto: message.content
    }));
});

discordClient.once('ready', () => {
    log('OK', `Discord conectado como ${discordClient.user.tag}`);
});

discordClient.on('error', (erro) => {
    log('ERRO', 'Discord:', erro.message);
});

discordClient.login(process.env.DISCORD_TOKEN).catch((erro) => {
    log('FATAL', 'Login do Discord falhou:', erro.message);
    process.exit(1);
});

// =================== CONEXAO TELEGRAM ======================
const telegramBot = new Telegraf(process.env.TELEGRAM_TOKEN);

telegramBot.on('text', async (ctx) => {
    await enviarParaN8N(criarPayload({
        origem: 'telegram',
        tipo: 'texto',
        timestamp: ctx.message.date * 1000,
        idCanal: ctx.chat.id,
        idUsuario: ctx.from.id,
        nomeUsuario: ctx.from.username || ctx.from.first_name,
        texto: ctx.message.text
    }));
});

telegramBot.on('voice', async (ctx) => {
    try {
        const fileLink = await ctx.telegram.getFileLink(ctx.message.voice.file_id);

        await enviarParaN8N(criarPayload({
            origem: 'telegram',
            tipo: 'audio',
            timestamp: ctx.message.date * 1000,
            idCanal: ctx.chat.id,
            idUsuario: ctx.from.id,
            nomeUsuario: ctx.from.username || ctx.from.first_name,
            urlDownload: fileLink.href
        }));
    } catch (error) {
        log('ERRO', 'Falha ao processar audio do Telegram:', error.message);
        await ctx.reply('Erro ao processar o audio.');
    }
});

telegramBot.on('photo', async (ctx) => {
    try {
        const fotos = ctx.message.photo;
        const melhorFoto = fotos[fotos.length - 1];
        const fileLink = await ctx.telegram.getFileLink(melhorFoto.file_id);

        await enviarParaN8N(criarPayload({
            origem: 'telegram',
            tipo: 'imagem',
            timestamp: ctx.message.date * 1000,
            idCanal: ctx.chat.id,
            idUsuario: ctx.from.id,
            nomeUsuario: ctx.from.username || ctx.from.first_name,
            urlDownload: fileLink.href
        }));
    } catch (error) {
        log('ERRO', 'Falha ao processar imagem do Telegram:', error.message);
        await ctx.reply('Erro ao processar a imagem.');
    }
});

// getMe() confirma a conexao. Nao uso o retorno do launch() porque a promise dele
// so resolve quando o bot PARA, nao quando conecta.
telegramBot.telegram.getMe()
    .then((info) => log('OK', `Telegram conectado como @${info.username}`))
    .catch((erro) => {
        log('FATAL', 'Conexao com o Telegram falhou:', erro.message);
        process.exit(1);
    });

// Long Polling evita a necessidade de configurar HTTPS/Webhooks para o Telegram no VPS
telegramBot.launch();

// Docker manda SIGTERM ao derrubar o container. Sem isto a morte e' silenciosa.
process.once('SIGINT', () => { log('STOP', 'SIGINT recebido'); telegramBot.stop('SIGINT'); });
process.once('SIGTERM', () => { log('STOP', 'SIGTERM recebido'); telegramBot.stop('SIGTERM'); });

// =================== FUNCAO CENTRALIZADORA DE ENVIO ======================
function criarPayload({
    origem,
    tipo,
    timestamp,
    idCanal,
    idUsuario,
    nomeUsuario,
    texto,
    urlDownload
}) {
    return {
        origem,
        tipo,
        timestamp: timestamp ? new Date(timestamp).toISOString() : new Date().toISOString(),
        idCanal: idCanal == null ? '' : String(idCanal),
        idUsuario: idUsuario == null ? '' : String(idUsuario),
        nomeUsuario: nomeUsuario || '',
        texto: texto || '',
        urlDownload: urlDownload || ''
    };
}

async function enviarParaN8N(payloadNormalizado) {
    const { origem, tipo, nomeUsuario } = payloadNormalizado;
    // Registro so metadado, nunca o conteudo da mensagem: log nao e' lugar de dado pessoal.
    log('RECEBIDO', `${origem}/${tipo} de ${nomeUsuario}`);

    try {
        const resposta = await axios.post(N8N_WEBHOOK_URL, payloadNormalizado);
        log('ENVIADO', `${origem}/${tipo} -> n8n HTTP ${resposta.status}`);
    } catch (error) {
        const status = error.response ? `HTTP ${error.response.status}` : 'sem resposta';
        log('ERRO', `${origem}/${tipo} -> n8n FALHOU (${status}):`, error.message);
    }
}
