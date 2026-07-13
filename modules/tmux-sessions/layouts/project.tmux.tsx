const Core = () => (
  <>
    <Terminal />
    <Codex />
    <Nvim focus />
  </>
)

const Runtime = () => (
  <Window id="runtime" name="runtime" index={3}>
    <Cols sizes="2fr 1fr">
      <Pane id="server" title="server" />
      <Rows>
        <Pane id="tests" title="tests" />
        <Pane id="shell" title="shell" />
      </Rows>
    </Cols>
  </Window>
)

export default (
  <Session root="$PROJECT_ROOT">
    <Core />
    <Runtime />
  </Session>
)
