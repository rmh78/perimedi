import { Sheet } from './Sheet'
import { useT } from '../i18n'
import { MorePanel } from './MorePanel'

/** Optional sheet wrapper around MorePanel (prefer /more route). */
export function MoreSheet({
  open,
  onClose,
}: {
  open: boolean
  onClose: () => void
}) {
  const t = useT()
  return (
    <Sheet open={open} title={t('more.title')} onClose={onClose} wide>
      <MorePanel />
    </Sheet>
  )
}
