import { _decorator, Color, Component, SpriteRenderer } from 'cc';

const { ccclass, executeInEditMode, executionOrder, property } = _decorator;

@ccclass('UnitySpriteRendererColorAdapter')
@executeInEditMode
@executionOrder(120)
export class UnitySpriteRendererColorAdapter extends Component {
    @property({ displayName: 'Color' })
    public color: Color = new Color(255, 255, 255, 255);

    @property({ displayName: 'Apply Material Color' })
    public applyMaterialColor = true;

    private _lastRendererApplied = '';
    private _lastMaterialApplied = '';
    private _materialColorSupported = true;

    protected onLoad (): void {
        this.applyColor();
    }

    protected onEnable (): void {
        this.applyColor();
    }

    protected onValidate (): void {
        this.applyColor();
    }

    protected lateUpdate (): void {
        this.applyColor();
    }

    private applyColor (): void {
        const renderer = this.getComponent(SpriteRenderer) as (SpriteRenderer & {
            _color?: Color;
            getMaterialInstance?: (index: number) => {
                getProperty?: (name: string) => unknown;
                setProperty?: (name: string, value: Color) => void;
            } | null;
        }) | null;
        if (!renderer) return;

        const appliedKey = `${this.color.r},${this.color.g},${this.color.b},${this.color.a}`;
        if (this._lastRendererApplied !== appliedKey) {
            renderer._color = this.color.clone();
            this._lastRendererApplied = appliedKey;
        }

        if (!this.applyMaterialColor || !this._materialColorSupported || !renderer.getMaterialInstance) return;
        if (this._lastMaterialApplied === appliedKey) return;

        const material = renderer.getMaterialInstance(0);
        if (!material || !material.setProperty) return;

        material.setProperty('mainColor', this.color);
        this._materialColorSupported = material.getProperty?.('mainColor') !== null;
        if (this._materialColorSupported) this._lastMaterialApplied = appliedKey;
    }
}
