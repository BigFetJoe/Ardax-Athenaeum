require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');
const { Telegraf } = require('telegraf');
const axios = require('axios');

const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

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

discordClient.login(process.env.DISCORD_TOKEN);

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
        console.error('Erro ao processar audio do Telegram:', error.message);
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
        console.error('Erro ao processar imagem do Telegram:', error.message);
        await ctx.reply('Erro ao processar a imagem.');
    }
});

// Long Polling evita a necessidade de configurar HTTPS/Webhooks para o Telegram no VPS
telegramBot.launch();

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
    try {
        await axios.post(N8N_WEBHOOK_URL, payloadNormalizado);
    } catch (error) {
        console.error(`Erro ao encaminhar evento de ${payloadNormalizado.origem}:`, error.message);
    }
}
