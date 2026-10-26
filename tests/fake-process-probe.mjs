// The HTTP fixture supplies its own fake game log and never controls real BO3.
// Keep the host machine's running processes from changing that fixture's state.
import {GameBridge} from '../companion/game.mjs';
GameBridge.prototype.checkProcess=function(){this.gameRunning=true;};
