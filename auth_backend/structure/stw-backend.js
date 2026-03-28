const { v4: uuidv4 } = require("uuid");
const { spawn, execSync } = require("child_process");

const stwSessions = new Map();
const accountToSessionId = new Map();
const hostState = {
  pid: 0,
  status: "IDLE",
  command: "",
  startedAt: null,
  lastError: ""
};

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function normalizeIdentifier(value, fallback = "Player") {
  if (!value || typeof value !== "string") return fallback;
  const cleaned = value.replace(/[\[\]'"`"]/g, "").trim();
  if (!cleaned) return fallback;
  if (cleaned.includes("@")) return cleaned.split("@")[0];
  return cleaned;
}

function detectModeFromRequest(req = {}) {
  const query = req.query || {};
  const body = (req.body && typeof req.body === "object") ? req.body : {};

  const profileId = (query.profileId || body.profileId || "").toString().toLowerCase();
  if (profileId === "campaign" || profileId === "theater0" || profileId === "outpost0") return "STW";

  const signals = [
    query.bucketId,
    query.playlist,
    query.playlistName,
    query.missionId,
    query.zoneName,
    body.bucketId,
    body.playlist,
    body.playlistName,
    body.missionId,
    body.zoneName
  ].map((value) => (value || "").toString().toLowerCase()).join(" ");

  if (signals.includes("stw") || signals.includes("campaign") || signals.includes("stonewood")) return "STW";
  return "BR";
}

function resolveAccountIdFromRequest(req = {}) {
  const params = req.params || {};
  const query = req.query || {};
  const body = (req.body && typeof req.body === "object") ? req.body : {};

  const wildcard = (params[0] || "").toString().trim();
  const wildcardFirst = wildcard.split(/[\/?&=,;:]+/g).map((token) => token.trim()).filter(Boolean)[0] || "";
  const partyPlayerIds = (query.partyPlayerIds || query.partyplayers || "").toString().split(",").map((entry) => entry.trim()).filter(Boolean);

  const candidates = [
    params.accountId,
    params.account_id,
    params.playerId,
    query.playerId,
    query.accountId,
    query.account_id,
    body.playerId,
    body.accountId,
    body.account_id,
    wildcardFirst,
    partyPlayerIds[0]
  ];

  for (const candidate of candidates) {
    const normalized = normalizeIdentifier((candidate || "").toString(), "");
    if (normalized) return normalized;
  }

  return "Player";
}

function resolveAccountIdFromOptions(options = {}) {
  const candidates = [
    options.accountId,
    options.playerId,
    options.ownerId,
    Array.isArray(options.partyPlayerIds) ? options.partyPlayerIds[0] : ""
  ];
  for (const candidate of candidates) {
    const normalized = normalizeIdentifier((candidate || "").toString(), "");
    if (normalized) return normalized;
  }
  return "Player";
}

function extractMissionSeed(req = {}) {
  const query = req.query || {};
  const body = (req.body && typeof req.body === "object") ? req.body : {};

  return {
    missionId: normalizeIdentifier((body.missionId || query.missionId || "stonewood_fts").toString(), "stonewood_fts"),
    zoneName: normalizeIdentifier((body.zoneName || query.zoneName || "Stonewood").toString(), "Stonewood"),
    theaterId: normalizeIdentifier((body.theaterId || query.theaterId || "theater_stonewood").toString(), "theater_stonewood"),
    difficulty: normalizeIdentifier((body.difficulty || query.difficulty || "Normal").toString(), "Normal")
  };
}

function listSessions() {
  return Array.from(stwSessions.values()).map((session) => clone(session));
}

function getSession(sessionId) {
  const session = stwSessions.get(sessionId);
  return session ? clone(session) : null;
}

function findSessionForAccount(accountId) {
  const normalizedAccountId = normalizeIdentifier(accountId);
  const existingSessionId = accountToSessionId.get(normalizedAccountId);
  if (existingSessionId) {
    const session = stwSessions.get(existingSessionId);
    if (session && (session.status === "QUEUED" || session.status === "IN_PROGRESS")) {
      return clone(session);
    }
  }

  for (const session of stwSessions.values()) {
    if (!Array.isArray(session.participants)) continue;
    const participantMatch = session.participants.some((participant) => participant.accountId === normalizedAccountId);
    if (participantMatch && (session.status === "QUEUED" || session.status === "IN_PROGRESS")) {
      accountToSessionId.set(normalizedAccountId, session.id);
      return clone(session);
    }
  }

  return null;
}

function ensureSession(accountId, seed = {}) {
  const normalizedAccountId = normalizeIdentifier(accountId);
  const existing = findSessionForAccount(normalizedAccountId);
  if (existing) return existing;

  const now = new Date().toISOString();
  const session = {
    id: `stw_${uuidv4().replace(/-/g, "")}`,
    mode: "STW",
    status: "QUEUED",
    ownerId: normalizedAccountId,
    missionId: normalizeIdentifier(seed.missionId || "stonewood_fts", "stonewood_fts"),
    zoneName: normalizeIdentifier(seed.zoneName || "Stonewood", "Stonewood"),
    theaterId: normalizeIdentifier(seed.theaterId || "theater_stonewood", "theater_stonewood"),
    difficulty: normalizeIdentifier(seed.difficulty || "Normal", "Normal"),
    maxPlayers: 4,
    region: "NAE",
    subregion: "NAE",
    participants: [
      {
        accountId: normalizedAccountId,
        joinedAt: now
      }
    ],
    createdAt: now,
    updatedAt: now
  };

  stwSessions.set(session.id, session);
  accountToSessionId.set(normalizedAccountId, session.id);
  return clone(session);
}

function joinSession(sessionId, accountId) {
  const session = stwSessions.get(sessionId);
  if (!session) return null;

  const normalizedAccountId = normalizeIdentifier(accountId);
  if (!session.participants.some((participant) => participant.accountId === normalizedAccountId)) {
    session.participants.push({
      accountId: normalizedAccountId,
      joinedAt: new Date().toISOString()
    });
    session.updatedAt = new Date().toISOString();
  }

  accountToSessionId.set(normalizedAccountId, session.id);
  return clone(session);
}

function startSession(sessionId) {
  const session = stwSessions.get(sessionId);
  if (!session) return null;
  if (session.status !== "IN_PROGRESS") {
    session.status = "IN_PROGRESS";
    session.updatedAt = new Date().toISOString();
  }
  return clone(session);
}

function buildSessionPayload(sessionId, gameServerConfig = {}, buildUniqueId = "0") {
  const session = getSession(sessionId);
  const maxPlayers = session ? Number(session.maxPlayers || 4) : 4;
  const participantsCount = session && Array.isArray(session.participants) ? session.participants.length : 1;

  return {
    id: sessionId,
    ownerId: normalizeIdentifier(session ? session.ownerId : "ProjectRebootHost", "ProjectRebootHost"),
    ownerName: "[DS]projectreboot-stw-host",
    serverName: "[DS]projectreboot-stw-host",
    serverAddress: (gameServerConfig.ip || "127.0.0.1").toString(),
    serverPort: Number(gameServerConfig.port || 7777),
    maxPublicPlayers: maxPlayers,
    openPublicPlayers: Math.max(0, maxPlayers - participantsCount),
    maxPrivatePlayers: 0,
    openPrivatePlayers: 0,
    attributes: {
      REGION_s: (session ? session.region : "NAE") || "NAE",
      GAMEMODE_s: "FORTCAMPAIGN",
      ALLOWBROADCASTING_b: true,
      SUBREGION_s: (session ? session.subregion : "NAE") || "NAE",
      DCID_s: "PROJECTREBOOT-STW",
      tenant_s: "Fortnite",
      MATCHMAKINGPOOL_s: "Any",
      STORMSHIELDDEFENSETYPE_i: 0,
      HOTFIXVERSION_i: 0,
      PLAYLISTNAME_s: "Campaign_Default",
      SESSIONKEY_s: `STW_${sessionId}`,
      TENANT_s: "Fortnite",
      BEACONPORT_i: 15009,
      BOTS_i: 0
    },
    publicPlayers: [],
    privatePlayers: [],
    totalPlayers: participantsCount,
    allowJoinInProgress: false,
    shouldAdvertise: false,
    isDedicated: false,
    usesStats: true,
    allowInvites: false,
    usesPresence: false,
    allowJoinViaPresence: true,
    allowJoinViaPresenceFriendsOnly: false,
    buildUniqueId: buildUniqueId || "0",
    lastUpdated: new Date().toISOString(),
    started: false
  };
}

function isProcessAlive(pid) {
  const parsedPid = Number(pid || 0);
  if (!Number.isFinite(parsedPid) || parsedPid <= 0) return false;
  try {
    process.kill(parsedPid, 0);
    return true;
  } catch (err) {
    return false;
  }
}

function isUdpPortListening(port) {
  const parsedPort = Number(port || 0);
  if (!Number.isFinite(parsedPort) || parsedPort <= 0) return false;

  try {
    execSync(`lsof -nP -iUDP:${parsedPort} | head -n 2`, { stdio: ["ignore", "pipe", "ignore"] });
    return true;
  } catch (err) {
    return false;
  }
}

function ensureHostRunning(gameServerConfig = {}) {
  const hostPort = Number(process.env.REBOOT_STW_HOST_PORT || gameServerConfig.port || 7777);
  const hostCommand = (process.env.REBOOT_STW_HOST_CMD || "").toString().trim();

  if (isUdpPortListening(hostPort)) {
    hostState.status = "READY_EXTERNAL";
    hostState.lastError = "";
    return clone(hostState);
  }

  if (isProcessAlive(hostState.pid)) {
    hostState.status = "STARTING";
    return clone(hostState);
  }

  if (!hostCommand) {
    hostState.status = "NO_COMMAND";
    hostState.lastError = "Set REBOOT_STW_HOST_CMD to auto-launch Project Reboot STW host.";
    return clone(hostState);
  }

  try {
    const shell = process.platform === "win32" ? (process.env.ComSpec || "cmd.exe") : "/bin/zsh";
    const args = process.platform === "win32" ? ["/c", hostCommand] : ["-lc", hostCommand];
    const child = spawn(shell, args, {
      detached: true,
      stdio: "ignore"
    });
    child.unref();

    hostState.pid = child.pid || 0;
    hostState.command = hostCommand;
    hostState.status = "LAUNCHED";
    hostState.startedAt = new Date().toISOString();
    hostState.lastError = "";
    return clone(hostState);
  } catch (err) {
    hostState.status = "ERROR";
    hostState.lastError = err.message;
    return clone(hostState);
  }
}

module.exports = {
  detectModeFromRequest,
  resolveAccountIdFromRequest,
  resolveAccountIdFromOptions,
  extractMissionSeed,
  ensureSession,
  getSession,
  findSessionForAccount,
  joinSession,
  startSession,
  listSessions,
  buildSessionPayload,
  ensureHostRunning
};
