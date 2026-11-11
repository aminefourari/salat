import handler from '@tanstack/react-start/server-entry'
import { d1Store, habousDayTimes, runCron } from './server/cron'
import { d1HabousStore } from './server/habous'
import { sendPush } from './server/push'

export default {
  fetch: handler.fetch,
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runCron(d1Store(env.DB), new Date(controller.scheduledTime), (row, p) => sendPush(env, row, p), habousDayTimes(d1HabousStore(env.DB))))
  },
}
