import { _decorator, Component } from 'cc';
import { GameTrackingService } from '../analytics/GameTrackingService.ts';
import superHtmlPlayable from './SuperHtmlPlayable.ts';

const { ccclass } = _decorator;

@ccclass('PlayableAdDownloadEvent')
export class PlayableAdDownloadEvent extends Component {
  onDownloadClick(eventOrUrl?: unknown, customUrl?: string): void {
    const url = customUrl
      || (typeof eventOrUrl === 'string' ? eventOrUrl : '')
      || superHtmlPlayable.get_download_url();

    GameTrackingService.logDownloadClick({ url });
    // End-card buttons must also work in browser Preview, where the super_html host
    // bridge is absent. The automatic flag enables the current-tab URL fallback.
    superHtmlPlayable.download({ automatic: true });
  }
}
