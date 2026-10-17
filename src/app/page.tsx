import { Suspense } from "react";
import { UserGreeting } from "@/components/auth/user-greeting";

export default function Home() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-4 p-4 text-center">
      <Suspense fallback={<p className="text-muted-foreground">Memuat...</p>}>
        <UserGreeting />
      </Suspense>
    </main>
  );
}
