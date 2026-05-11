import { useSuspenseQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Suspense } from "react"

import { MetricsService } from "@/client"
import { readUserMeForGuard } from "@/routeAuth"
import Forbidden from "@/components/Common/Forbidden"
import { Skeleton } from "@/components/ui/skeleton"
import { canViewMetrics } from "@/permissions"

function getMetricsQueryOptions() {
  return {
    queryFn: MetricsService.readMetrics,
    queryKey: ["metrics"],
  }
}

export const Route = createFileRoute("/_layout/metrics")({
  component: Metrics,
  beforeLoad: async () => {
    const user = await readUserMeForGuard()
    return { canViewMetrics: canViewMetrics(user) }
  },
  head: () => ({
    meta: [
      {
        title: "Metrics - FastAPI Template",
      },
    ],
  }),
})

function MetricsContent() {
  const { data } = useSuspenseQuery(getMetricsQueryOptions())

  return (
    <div className="grid gap-4 md:grid-cols-2">
      <div className="rounded-lg border p-6">
        <p className="text-sm font-medium text-muted-foreground">Users</p>
        <p className="mt-2 text-3xl font-bold">{data.users}</p>
      </div>
      <div className="rounded-lg border p-6">
        <p className="text-sm font-medium text-muted-foreground">Items</p>
        <p className="mt-2 text-3xl font-bold">{data.items}</p>
      </div>
      <div className="rounded-lg border p-6 md:col-span-2">
        <p className="text-sm font-medium text-muted-foreground">Summary</p>
        <p className="mt-2">{data.summary}</p>
      </div>
    </div>
  )
}

function MetricsPending() {
  return (
    <div className="grid gap-4 md:grid-cols-2">
      <Skeleton className="h-32" />
      <Skeleton className="h-32" />
    </div>
  )
}

function Metrics() {
  const { canViewMetrics } = Route.useRouteContext()

  if (!canViewMetrics) {
    return <Forbidden message="Only admins and managers can view metrics." />
  }

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Metrics</h1>
        <p className="text-muted-foreground">
          Lightweight operational insights for admins and managers.
        </p>
      </div>
      <Suspense fallback={<MetricsPending />}>
        <MetricsContent />
      </Suspense>
    </div>
  )
}
