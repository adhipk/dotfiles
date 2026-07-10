type TmuxElement = unknown
type TmuxComponent = (props: Record<string, unknown>) => TmuxElement

declare const h: (...args: unknown[]) => TmuxElement
declare const Fragment: TmuxComponent
declare const Session: TmuxComponent
declare const Window: TmuxComponent
declare const Pane: TmuxComponent
declare const Rows: TmuxComponent
declare const Cols: TmuxComponent
declare const Terminal: TmuxComponent
declare const Codex: TmuxComponent
declare const Nvim: TmuxComponent

declare namespace JSX {
  type Element = TmuxElement
  interface ElementChildrenAttribute {
    children: unknown
  }
}
