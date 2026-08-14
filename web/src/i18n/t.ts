import type { MessageParams, Messages } from './types'

/** Replace `{{key}}` placeholders in a message template. */
export function translate(
  messages: Messages,
  key: string,
  params?: MessageParams,
): string {
  const template = messages[key] ?? key
  if (!params) return template
  return template.replace(/\{\{(\w+)\}\}/g, (_, name: string) => {
    const value = params[name]
    return value === undefined || value === null ? '' : String(value)
  })
}
