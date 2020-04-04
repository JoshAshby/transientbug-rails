import Behavior, { ZobBehavior, ValueBinding } from "../lib/Zob"

import store from "../store/store"

@ZobBehavior("bulk-action-visibility")
export default class BulkActionVisibilityBehavior extends Behavior {
  protected unsubscribe: any

  @ValueBinding hasNoSelection = true

  Setup = () => {
    this.unsubscribe = store.subscribe(this.subscriber)
  }

  Teardown = () => {
    this.unsubscribe()
  }

  protected subscriber = () => {
    const { selection } = store.getState()
    this.hasNoSelection = selection.selection.length === 0
  }
}
