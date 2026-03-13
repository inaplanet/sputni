const http = require("http");
const WebSocket = require("ws");

const PORT = process.env.PORT || 10000;
const HOST = "0.0.0.0";

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Hello Aether!");
    return;
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

const wss = new WebSocket.Server({
  server,
  path: "/ws",
});

// roomId => Set<WebSocket>
const rooms = new Map();

// socket => { roomId, peerId, role }
const peers = new Map();

function safeSend(ws, data) {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function broadcastToRoomExcept(roomId, sender, message) {
  const room = rooms.get(roomId);
  if (!room) return;

  for (const client of room) {
    if (client !== sender && client.readyState === WebSocket.OPEN) {
      safeSend(client, message);
    }
  }
}

function removePeer(ws) {
  const info = peers.get(ws);
  if (!info) return;

  const { roomId, peerId } = info;
  const room = rooms.get(roomId);

  if (room) {
    room.delete(ws);

    if (room.size === 0) {
      rooms.delete(roomId);
    }
  }

  peers.delete(ws);
  console.log(`Peer disconnected: ${peerId || "unknown"} from room ${roomId || "unknown"}`);
}

wss.on("connection", (ws, req) => {
  console.log("New WS connection");

  ws.on("message", (raw) => {
    try {
      const msg = JSON.parse(raw.toString());
      const { type, payload } = msg || {};

      if (!type) {
        safeSend(ws, {
          type: "error",
          payload: { message: "Missing message type" },
        });
        return;
      }

      if (type === "join") {
        const roomId = payload?.roomId;
        const peerId = payload?.peerId || `peer-${Math.random().toString(36).slice(2, 8)}`;
        const role = payload?.role || "unknown";

        if (!roomId) {
          safeSend(ws, {
            type: "error",
            payload: { message: "Missing roomId in join payload" },
          });
          return;
        }

        if (role !== "camera" && role !== "monitor") {
          safeSend(ws, {
            type: "error",
            payload: { message: "Invalid role in join payload" },
          });
          return;
        }

        removePeer(ws);

        if (!rooms.has(roomId)) {
          rooms.set(roomId, new Set());
        }

        const room = rooms.get(roomId);
        const roomPeers = [...room].map((client) => peers.get(client)).filter(Boolean);

        if (roomPeers.some((peer) => peer.role === role)) {
          safeSend(ws, {
            type: "error",
            payload: { message: `Room already has an active ${role}` },
          });
          return;
        }

        if (roomPeers.length >= 2) {
          safeSend(ws, {
            type: "error",
            payload: { message: "Room is already full" },
          });
          return;
        }

        room.add(ws);
        peers.set(ws, { roomId, peerId, role });

        console.log(`Peer joined room=${roomId} peerId=${peerId} role=${role}`);

        for (const peer of roomPeers) {
          safeSend(ws, {
            type: "join",
            payload: {
              roomId,
              peerId: peer.peerId,
              role: peer.role,
            },
          });
        }

        broadcastToRoomExcept(roomId, ws, {
          type: "join",
          payload: { roomId, peerId, role },
        });

        return;
      }

      const peerInfo = peers.get(ws);
      if (!peerInfo) {
        safeSend(ws, {
          type: "error",
          payload: { message: "Must join room before sending signaling messages" },
        });
        return;
      }

      const { roomId, peerId } = peerInfo;

      switch (type) {
        case "offer":
        case "answer":
        case "ice-candidate":
        case "control":
          broadcastToRoomExcept(roomId, ws, {
            type,
            payload: {
              ...payload,
              fromPeerId: peerId,
              roomId,
            },
          });
          console.log(`Relayed ${type} in room=${roomId} from=${peerId}`);
          break;

        default:
          safeSend(ws, {
            type: "error",
            payload: { message: `Unsupported message type: ${type}` },
          });
      }
    } catch (err) {
      console.error("Invalid message:", err);
      safeSend(ws, {
        type: "error",
        payload: { message: "Invalid JSON" },
      });
    }
  });

  ws.on("close", () => {
    removePeer(ws);
  });

  ws.on("error", (err) => {
    console.error("Socket error:", err);
    removePeer(ws);
  });
});

// server.listen(PORT, "192.168.0.108", () => {
//   console.log(`Signaling server running on http://192.168.0.108:${PORT}`);
//   console.log(`WebSocket endpoint: ws://192.168.0.108:${PORT}/ws`);
// });

server.listen(PORT, HOST, () => {
  console.log(`Signaling server running on http://${HOST}:${PORT}`);
  console.log(`WebSocket endpoint: /ws`);
});
