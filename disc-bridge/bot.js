require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');
const { Telegraf } = require('telegraf');
const axios = require('axios');

const N8N_WEBHOOK_URL = process.env.N8N_WEBHOOK_URL;

// ==========================================
// 1. CONEXÃO DISCORD
// ==========================================
const discordClient = new Client({
    intents: [GatewayIntentBits.Guilds, 
              GatewayIntentBits.GuildMessages,
              GatewayIntentBits.MessageContent
              ]
});

discordClient.on('messageCreate', async (message) => {
    if (message.author.bot) return;

    await enviarParaN8N({
        origem: 'discord',
        idCanal: message.channel.id,
        idUsuario: message.author.id,
        nomeUsuario: message.author.username,
        texto: message.content
    });
});

discordClient.login(process.env.DISCORD_TOKEN);

// ==========================================
// 2. CONEXÃO TELEGRAM (Via Long Polling)
// ==========================================
const telegramBot = new Telegraf(process.env.TELEGRAM_TOKEN);

telegramBot.on('text', async (ctx) => {
    await enviarParaN8N({
        origem: 'telegram',
        idCanal: ctx.chat.id.toString(),
        idUsuario: ctx.from.id.toString(),
        nomeUsuario: ctx.from.username || ctx.from.first_name,
        texto: ctx.message.text
    });
});

// Long Polling evita a necessidade de configurar HTTPS/Webhooks para o Telegram no VPS
telegramBot.launch();

// ==========================================
// 3. FUNÇÃO CENTRALIZADORA DE ENVIO
// ==========================================
async function enviarParaN8N(payloadNormalizado) {
    try {
        await axios.post(N8N_WEBHOOK_URL, payloadNormalizado);
    } catch (error) {
        console.error(`Erro ao encaminhar evento de ${payloadNormalizado.origem}:`, error.message);
    }
}
