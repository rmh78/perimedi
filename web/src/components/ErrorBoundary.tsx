import { Component, type ErrorInfo, type ReactNode } from 'react'

type Props = { children: ReactNode }
type State = { error: Error | null }

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('PeriMedi render error', error, info.componentStack)
  }

  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="mx-auto max-w-md px-4 py-10 text-center">
        <p className="font-display text-2xl font-semibold text-blush-900">
          Something went wrong
        </p>
        <p className="mt-2 text-sm text-ink-soft">
          Reload the page. Your data stays in this browser.
        </p>
        <button
          type="button"
          className="btn-primary mt-4 !min-h-10 !px-4 text-sm"
          onClick={() => window.location.reload()}
        >
          Reload
        </button>
      </div>
    )
  }
}
