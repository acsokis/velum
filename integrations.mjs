// Deliberately offline adapters. No OAuth tokens, network calls or automatic forwarding.
export class MockService {
  constructor(name){this.name=name;this.mode='mock';this.connected=false;this.events=[];this.sequence=0;this.hidePreview=true;}
  connect(){this.connected=true;return this.snapshot();}
  disconnect(){this.connected=false;this.events=[];return this.snapshot();}
  emit(){if(!this.connected)throw [409,'Mock adapter disconnected'];const event={id:++this.sequence,service:this.name,mode:'MOCK',timestamp:new Date().toISOString(),type:this.name==='Twitch'?'channel.event':'game.invitation',text:this.name==='Twitch'?'MOCK channel event — no Twitch account connected':'MOCK game invitation — no Discord account connected'};this.events.push(event);this.events=this.events.slice(-20);return event;}
  snapshot(){return {mode:this.mode,connected:this.connected,privacy:'previews hidden by default',events:this.events};}
}
