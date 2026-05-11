import { Link } from "@tanstack/react-router"

import { Button } from "@/components/ui/button"

type ForbiddenProps = {
  title?: string
  message?: string
}

const Forbidden = ({
  title = "Access denied",
  message = "You do not have permission to view this page.",
}: ForbiddenProps) => (
  <div className="flex min-h-[50vh] flex-col items-center justify-center gap-4 text-center">
    <div>
      <h1 className="text-2xl font-bold tracking-tight">{title}</h1>
      <p className="mt-2 text-muted-foreground">{message}</p>
    </div>
    <Link to="/">
      <Button>Go to dashboard</Button>
    </Link>
  </div>
)

export default Forbidden
