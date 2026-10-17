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
import { signUp } from "@/lib/auth/actions";
import type { AuthFormState } from "@/lib/auth/schemas";

const initialState: AuthFormState = {};

export function SignUpForm() {
  const [state, formAction, isPending] = useActionState(signUp, initialState);

  return (
    <Card className="w-full max-w-sm">
      <CardHeader>
        <CardTitle>Daftar</CardTitle>
        <CardDescription>Buat akun siswa baru.</CardDescription>
      </CardHeader>
      <form action={formAction}>
        <CardContent className="flex flex-col gap-4">
          <AuthField
            name="fullName"
            label="Nama lengkap"
            autoComplete="name"
            defaultValue={state.values?.fullName}
            errors={state.fieldErrors?.fullName}
          />
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
            autoComplete="new-password"
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
            {isPending ? "Memproses..." : "Daftar"}
          </Button>
          <p className="text-sm text-muted-foreground">
            Sudah punya akun?{" "}
            <Link href="/masuk" className="underline">
              Masuk
            </Link>
          </p>
        </CardFooter>
      </form>
    </Card>
  );
}
