const functions = require("./functions.js");
const stwBackend = require("./stw-backend.js");

module.exports = async (ws, options = {}) => {
  const mode = ((options.mode || "BR").toString().toUpperCase() === "STW") ? "STW" : "BR";
  const isStw = mode === "STW";

  let stwSession = null;
  let accountId = "";
  let queuedPlayers = 0;
  let connectedPlayers = 1;
  let playlistName = "Playlist_DefaultSolo";

  if (isStw) {
    accountId = stwBackend.resolveAccountIdFromOptions(options);
    stwSession = stwBackend.ensureSession(accountId, {
      missionId: options.missionId || "stonewood_fts",
      zoneName: options.zoneName || "Stonewood",
      theaterId: options.theaterId || "theater_stonewood",
      difficulty: options.difficulty || "Normal"
    });
    stwSession = stwBackend.joinSession(stwSession.id, accountId) || stwSession;
    stwBackend.startSession(stwSession.id);
    stwBackend.ensureHostRunning(options.gameServerConfig || {});

    connectedPlayers = Math.max(1, Array.isArray(stwSession.participants) ? stwSession.participants.length : 1);
    queuedPlayers = Math.max(0, Number(stwSession.maxPlayers || 4) - connectedPlayers);
    playlistName = "Campaign_Default";
  }

  const ticketId = functions.MakeID().replace(/-/gi, "");
  const matchId = functions.MakeID().replace(/-/gi, "");
  const sessionId = isStw && stwSession ? stwSession.id : functions.MakeID().replace(/-/gi, "");

  Connecting();
  await functions.sleep(500);
  Waiting();
  await functions.sleep(800);
  Queued();
  await functions.sleep(900);
  SessionAssignment();
  await functions.sleep(900);
  Join();

  function Connecting() {
    ws.send(
      JSON.stringify({
        payload: {
          state: "Connecting",
        },
        name: "StatusUpdate",
      })
    );
  }

  function Waiting() {
    ws.send(
      JSON.stringify({
        payload: {
          totalPlayers: connectedPlayers,
          connectedPlayers: connectedPlayers,
          mode: mode,
          state: "Waiting",
        },
        name: "StatusUpdate",
      })
    );
  }

  function Queued() {
    ws.send(
      JSON.stringify({
        payload: {
          ticketId: ticketId,
          queuedPlayers: queuedPlayers,
          estimatedWaitSec: 0,
          mode: mode,
          status: {},
          state: "Queued",
        },
        name: "StatusUpdate",
      })
    );
  }

  function SessionAssignment() {
    ws.send(
      JSON.stringify({
        payload: {
          matchId: matchId,
          mode: mode,
          state: "SessionAssignment",
        },
        name: "StatusUpdate",
      })
    );
  }

  function Join() {
    ws.send(
      JSON.stringify({
        payload: {
          matchId: matchId,
          sessionId: sessionId,
          joinDelaySec: 1,
          playlistName: playlistName
        },
        name: "Play",
      })
    );
  }
};
