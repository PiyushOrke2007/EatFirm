import dgram from 'node:dgram';

const DISCOVERY_MESSAGE = 'EATFIRM_DISCOVERY_V1';

export function startLanDiscovery(port: number, apiPort: number) {
  const socket = dgram.createSocket('udp4');
  let closed = false;

  socket.on('error', (error) => {
    console.warn(`LAN discovery unavailable: ${error.message}`);
    socket.close();
    closed = true;
  });

  socket.on('message', (message, remote) => {
    if (message.toString().trim() !== DISCOVERY_MESSAGE) {
      return;
    }

    socket.send(
      Buffer.from(
        JSON.stringify({
          service: 'eatfirm-api',
          port: apiPort,
        }),
      ),
      remote.port,
      remote.address,
    );
  });

  socket.bind(port, '0.0.0.0', () => {
    socket.setBroadcast(true);
    console.info(`LAN discovery listening on UDP ${port}`);
  });

  return {
    close: () => {
      if (!closed) {
        socket.close();
        closed = true;
      }
    },
  };
}
