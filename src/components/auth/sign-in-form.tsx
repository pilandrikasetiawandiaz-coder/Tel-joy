"use client";

import Link from "next/link";
import { useActionState } from "react";
import { AuthField } from "@/components/auth/auth-field";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { signIn } from "@/lib/auth/actions";
import type { AuthFormState } from "@/lib/auth/schemas";

const initialState: AuthFormState = {};

export function SignInForm() {
  const [state, formAction, isPending] = useActionState(signIn, initialState);

  return (
    <Card className="w-full max-w-sm">
      <CardHeader>
        <CardTitle>Masuk</CardTitle>
        <CardDescription>Masuk untuk mulai belajar.</CardDescription>
      </CardHeader>
      <form action={formAction}>
        <CardContent className="flex flex-col gap-4">
          <AuthField
            name="email"
            label="Email"
            type="email"
            autoComplete="email"
            defaultValue={state.values?.email}
            errors={state.fieldErrors?.email}
          />
          <AuthField
            name="password"
            label="Kata sandi"
            type="password"
            autoComplete="current-password"
            errors={state.fieldErrors?.password}
          />
          {state.message && (
            <p role="alert" className="text-sm text-destructive">
              {state.message}
            </p>
          )}
        </CardContent>
        <CardFooter className="mt-4 flex flex-col gap-3">
          <Button type="submit" className="w-full" disabled={isPending}>
            {isPending ? "Memproses..." : "Masuk"}
          </Button>
          <p className="text-sm text-muted-foreground">
            Belum punya akun?{" "}
            <Link href="/daftar" className="underline">
              Daftar
            </Link>
          </p>
        </CardFooter>
      </form>
    </Card>
  );
}
