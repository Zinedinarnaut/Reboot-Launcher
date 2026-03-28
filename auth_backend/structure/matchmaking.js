const Express = require("express");
const express = Express.Router();
const fs = require("fs");
const path = require("path");
const iniparser = require("ini");
const config = iniparser.parse(fs.readFileSync(path.join(__dirname, "..", "Config", "config.ini")).toString());
const functions = require("./functions.js");
const stwBackend = require("./stw-backend.js");

function debugMatchmaking(event, payload = {}) {
    const debugEnabled = (process.env.REBOOT_DEBUG_MATCHMAKING || "").toString().toLowerCase();
    if (debugEnabled !== "1" && debugEnabled !== "true" && debugEnabled !== "yes" && debugEnabled !== "on") return;
    try {
        console.log(`[reboot:matchmaking] ${event}`, JSON.stringify(payload));
    } catch (err) {
        console.log(`[reboot:matchmaking] ${event}`, payload);
    }
}

function detectMode(req) {
    const requestMode = stwBackend.detectModeFromRequest(req);
    if (requestMode === "STW") return "STW";

    const cookieMode = ((req.cookies.currentMatchmakingMode || req.cookies.currentGameModeHint || "").toString().toUpperCase());
    if (cookieMode === "STW") return "STW";

    return "BR";
}

function normalizeIdentifier(value, fallback = "") {
    if (!value || typeof value !== "string") return fallback;
    const cleaned = value.replace(/[\[\]'"`"]/g, "").trim();
    if (!cleaned) return fallback;
    if (cleaned.includes("@")) return cleaned.split("@")[0];
    return cleaned;
}

function resolveAccountId(req) {
    const byRequest = stwBackend.resolveAccountIdFromRequest(req);
    if (byRequest && byRequest !== "Player") return byRequest;

    const byCookie = normalizeIdentifier((req.cookies.currentMatchmakingAccountId || "").toString(), "");
    if (byCookie) return byCookie;

    return byRequest || "Player";
}

function setCommonMatchmakingCookies(req, res, mode, accountId = "") {
    const bucketId = (req.query.bucketId || "").toString();
    if (bucketId.includes(":")) {
        res.cookie("currentbuildUniqueId", bucketId.split(":")[0]);
    } else if (bucketId) {
        res.cookie("currentbuildUniqueId", bucketId);
    }

    res.cookie("currentMatchmakingMode", mode);
    res.cookie("currentGameModeHint", mode, { maxAge: 1000 * 60 * 15 });

    if (accountId) {
        res.cookie("currentMatchmakingAccountId", accountId, { maxAge: 1000 * 60 * 10 });
    }
}

function ensureStwSession(req, res) {
    const accountId = resolveAccountId(req);
    const seed = stwBackend.extractMissionSeed(req);

    let session = stwBackend.ensureSession(accountId, seed);
    session = stwBackend.joinSession(session.id, accountId) || session;

    const hostState = stwBackend.ensureHostRunning(config.GameServer);

    setCommonMatchmakingCookies(req, res, "STW", accountId);

    debugMatchmaking("ensureStwSession", {
        accountId: accountId,
        sessionId: session.id,
        missionId: session.missionId,
        zoneName: session.zoneName,
        hostStatus: hostState.status,
        hostPid: hostState.pid || 0
    });

    return { accountId, session, hostState };
}

function extractSessionIdFromJoinRoute(req) {
    const direct = normalizeIdentifier((req.params[0] || "").toString(), "");
    if (direct) return direct;

    const originalUrl = (req.originalUrl || "").toString();
    const match = originalUrl.match(/\/fortnite\/api\/(?:game\/v2\/)?(?:matchmakingservice|matchmaking)\/session\/([^\/?]+)\/join/i);
    if (match && match[1]) return normalizeIdentifier(match[1], "");

    return "";
}

function buildBrSessionPayload(sessionId, req) {
    return {
        id: sessionId,
        ownerId: functions.MakeID().replace(/-/ig, "").toUpperCase(),
        ownerName: "[DS]projectreboot-br-host",
        serverName: "[DS]projectreboot-br-host",
        serverAddress: config.GameServer.ip,
        serverPort: Number(config.GameServer.port),
        maxPublicPlayers: 100,
        openPublicPlayers: 99,
        maxPrivatePlayers: 0,
        openPrivatePlayers: 0,
        attributes: {
            REGION_s: "NAE",
            GAMEMODE_s: "FORTATHENA",
            ALLOWBROADCASTING_b: true,
            SUBREGION_s: "NAE",
            DCID_s: "PROJECTREBOOT-BR",
            tenant_s: "Fortnite",
            MATCHMAKINGPOOL_s: "Any",
            STORMSHIELDDEFENSETYPE_i: 0,
            HOTFIXVERSION_i: 0,
            PLAYLISTNAME_s: "Playlist_DefaultSolo",
            SESSIONKEY_s: functions.MakeID().replace(/-/ig, "").toUpperCase(),
            TENANT_s: "Fortnite",
            BEACONPORT_i: 15009,
            BOTS_i: 0
        },
        publicPlayers: [],
        privatePlayers: [],
        totalPlayers: 1,
        allowJoinInProgress: false,
        shouldAdvertise: false,
        isDedicated: false,
        usesStats: false,
        allowInvites: false,
        usesPresence: false,
        allowJoinViaPresence: true,
        allowJoinViaPresenceFriendsOnly: false,
        buildUniqueId: req.cookies.currentbuildUniqueId || "0",
        lastUpdated: new Date().toISOString(),
        started: false
    };
}

async function handleFindPlayer(req, res) {
    const mode = detectMode(req);
    if (mode !== "STW") return res.json([]);

    const stwContext = ensureStwSession(req, res);
    return res.json([{
        accountId: stwContext.accountId,
        sessionId: stwContext.session.id,
        status: stwContext.session.status,
        mode: "STW",
        missionId: stwContext.session.missionId
    }]);
}

express.get("/fortnite/api/matchmaking/session/findPlayer/*", handleFindPlayer);
express.get("/fortnite/api/game/v2/matchmakingservice/findPlayer/*", handleFindPlayer);

async function handleTicket(req, res) {
    const mode = detectMode(req);
    const accountId = resolveAccountId(req);

    if (mode === "STW") {
        const stwContext = ensureStwSession(req, res);
        const encodedAccount = encodeURIComponent(stwContext.accountId);
        res.json({
            serviceUrl: `ws://127.0.0.1/matchmaking/stw?accountId=${encodedAccount}&missionId=${encodeURIComponent(stwContext.session.missionId)}`,
            ticketType: "mms-player-stw",
            payload: "69=",
            signature: "420="
        });
        return res.end();
    }

    setCommonMatchmakingCookies(req, res, mode, accountId);

    res.json({
        serviceUrl: "ws://127.0.0.1/matchmaking",
        ticketType: "mms-player",
        payload: "69=",
        signature: "420="
    });
    return res.end();
}

express.get("/fortnite/api/game/v2/matchmakingservice/ticket/player/*", handleTicket);
express.get("/fortnite/api/matchmakingservice/ticket/player/*", handleTicket);

function handleAccountSession(req, res) {
    res.json({
        accountId: req.params.accountId,
        sessionId: req.params.sessionId,
        key: "AOJEv8uTFmUh7XM2328kq9rlAzeQ5xzWzPIiyKn2s7s="
    });
}

express.get("/fortnite/api/game/v2/matchmaking/account/:accountId/session/:sessionId", handleAccountSession);
express.get("/fortnite/api/game/v2/matchmakingservice/account/:accountId/session/:sessionId", handleAccountSession);

async function handleSessionById(req, res) {
    const sessionId = req.params.session_id;
    const stwSession = stwBackend.getSession(sessionId);

    if (stwSession) {
        const payload = stwBackend.buildSessionPayload(sessionId, config.GameServer, req.cookies.currentbuildUniqueId || "0");
        return res.json(payload);
    }

    const cookieMode = ((req.cookies.currentMatchmakingMode || "").toString().toUpperCase());
    if (cookieMode === "STW") {
        const stwContext = ensureStwSession(req, res);
        const payload = stwBackend.buildSessionPayload(stwContext.session.id, config.GameServer, req.cookies.currentbuildUniqueId || "0");
        return res.json(payload);
    }

    return res.json(buildBrSessionPayload(sessionId, req));
}

express.get("/fortnite/api/matchmaking/session/:session_id", handleSessionById);
express.get("/fortnite/api/game/v2/matchmakingservice/session/:session_id", handleSessionById);

async function handleSessionJoin(req, res) {
    const sessionId = extractSessionIdFromJoinRoute(req);
    const existingSession = sessionId ? stwBackend.getSession(sessionId) : null;

    if (existingSession) {
        const accountId = resolveAccountId(req);
        stwBackend.joinSession(sessionId, accountId);
        stwBackend.startSession(sessionId);
        stwBackend.ensureHostRunning(config.GameServer);
    }

    res.status(204);
    res.end();
}

express.post("/fortnite/api/matchmaking/session/*/join", handleSessionJoin);
express.post("/fortnite/api/game/v2/matchmakingservice/session/*/join", handleSessionJoin);

async function handleMatchMakingRequest(req, res) {
    const mode = detectMode(req);
    if (mode !== "STW") return res.json([]);

    const stwContext = ensureStwSession(req, res);
    return res.json([{
        accountId: stwContext.accountId,
        sessionId: stwContext.session.id,
        mode: "STW",
        missionId: stwContext.session.missionId,
        status: stwContext.session.status
    }]);
}

express.post("/fortnite/api/matchmaking/session/matchMakingRequest", handleMatchMakingRequest);
express.post("/fortnite/api/game/v2/matchmakingservice/matchMakingRequest", handleMatchMakingRequest);

module.exports = express;
