import handler from '@tanstack/react-start/server-entry'
import { d1Store, habousDayTimes, prefetchHabous, runCron } from './server/cron'
import { d1HabousStore } from './server/habous'
import { sendPush } from './server/push'

export default {
  fetch: handler.fetch,
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    const now = new Date(controller.scheduledTime), habous = d1HabousStore(env.DB)
    ctx.waitUntil(runCron(d1Store(env.DB), now, (row, p) => sendPush(env, row, p), habousDayTimes(habous)))
    ctx.waitUntil(prefetchHabous(habous, now).catch(err => console.error('habous prefetch failed', err)))
  },
}
