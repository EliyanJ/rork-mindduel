import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  Ban,
  Check,
  Copy,
  Download,
  Gift,
  Loader2,
  RefreshCw,
  RotateCcw,
  Search,
  Trash2,
  Users,
} from "lucide-react";
import { useCallback, useMemo, useState } from "react";

import { useAdminAuth } from "@/hooks/useAdminAuth";
import { toast } from "@/hooks/use-toast";
import {
  ADMIN_ROLES,
  ROLE_HELP,
  ROLE_LABELS,
  auditLabel,
  deleteUserAccount,
  exportUserData,
  fetchAudit,
  fetchRefunds,
  fetchUserDetail,
  fetchUsers,
  formatAmount,
  formatDate,
  relativeTime,
  setGrantedPremium,
  setUserRole,
  type AdminRole,
  type AdminUserSummary,
} from "@/lib/adminUsers";

type Tab = "users" | "refunds" | "audit";

const INACTIVE_OPTIONS = [
  { value: 0, label: "Tous" },
  { value: 7, label: "Inactifs 7 j+" },
  { value: 30, label: "Inactifs 30 j+" },
  { value: 90, label: "Inactifs 90 j+" },
] as const;

const ROLE_STYLES: Record<AdminRole, string> = {
  standard: "border-white/10 bg-white/[0.04] text-white/60",
  beta: "border-sky-400/30 bg-sky-400/10 text-sky-200",
  premium: "border-amber-400/30 bg-amber-400/10 text-amber-200",
  admin: "border-violet-400/30 bg-violet-400/10 text-violet-200",
  banned: "border-red-500/30 bg-red-500/10 text-red-300",
};

/**
 * Account administration: who uses Minduel, what role they hold, whether they
 * were offered premium, and every Apple refund. Purchased subscriptions are
 * read-only here on purpose — Apple owns that state.
 */
const AdminUsers = () => {
  const { session } = useAdminAuth();
  const actor = session?.label ?? "admin";
  const queryClient = useQueryClient();

  const [tab, setTab] = useState<Tab>("users");
  const [searchInput, setSearchInput] = useState<string>("");
  const [search, setSearch] = useState<string>("");
  const [roleFilter, setRoleFilter] = useState<AdminRole | "all">("all");
  const [inactiveDays, setInactiveDays] = useState<number>(0);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);

  const usersQuery = useQuery({
    queryKey: ["admin-users", search, roleFilter, inactiveDays],
    queryFn: () => fetchUsers({ search, role: roleFilter, inactiveDays }),
  });

  const detailQuery = useQuery({
    queryKey: ["admin-user-detail", selectedId],
    queryFn: () => fetchUserDetail(selectedId as string),
    enabled: selectedId !== null,
  });

  const refundsQuery = useQuery({
    queryKey: ["admin-refunds"],
    queryFn: fetchRefunds,
    enabled: tab === "refunds",
  });

  const auditQuery = useQuery({
    queryKey: ["admin-audit"],
    queryFn: () => fetchAudit(150),
    enabled: tab === "audit",
  });

  const invalidate = useCallback(() => {
    void queryClient.invalidateQueries({ queryKey: ["admin-users"] });
    void queryClient.invalidateQueries({ queryKey: ["admin-user-detail"] });
    void queryClient.invalidateQueries({ queryKey: ["admin-audit"] });
  }, [queryClient]);

  const roleMutation = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: AdminRole }) =>
      setUserRole(userId, role, actor),
    onSuccess: (user) => {
      toast({ title: `${user.name} → ${ROLE_LABELS[user.role]}` });
      invalidate();
    },
    onError: (err: Error) => toast({ title: "Échec", description: err.message, variant: "destructive" }),
  });

  const premiumMutation = useMutation({
    mutationFn: ({ userId, grant }: { userId: string; grant: boolean }) =>
      setGrantedPremium(userId, grant, actor),
    onSuccess: (data) => {
      toast({
        title: data.access.grantedPremium ? "Premium offert" : "Premium retiré",
        description: data.user.name,
      });
      invalidate();
    },
    onError: (err: Error) => toast({ title: "Échec", description: err.message, variant: "destructive" }),
  });

  const deleteMutation = useMutation({
    mutationFn: (userId: string) => deleteUserAccount(userId, actor),
    onSuccess: () => {
      toast({ title: "Compte supprimé", description: "Les données serveur ont été effacées." });
      setSelectedId(null);
      setConfirmDelete(null);
      invalidate();
    },
    onError: (err: Error) => toast({ title: "Échec", description: err.message, variant: "destructive" }),
  });

  const exportMutation = useMutation({
    mutationFn: (userId: string) => exportUserData(userId, actor),
    onSuccess: (data, userId) => {
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `minduel-export-${userId}.json`;
      link.click();
      URL.revokeObjectURL(url);
      toast({ title: "Export téléchargé" });
    },
    onError: (err: Error) => toast({ title: "Échec", description: err.message, variant: "destructive" }),
  });

  const stats = usersQuery.data;
  const users = useMemo<AdminUserSummary[]>(() => stats?.users ?? [], [stats]);
  const selected = detailQuery.data;

  const submitSearch = useCallback(() => setSearch(searchInput.trim()), [searchInput]);

  return (
    <div className="mx-auto max-w-[1600px] px-4 py-6 text-white">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="flex items-center gap-2 text-2xl font-extrabold tracking-tight">
            <span className="grid h-8 w-8 place-items-center rounded-xl bg-gradient-to-br from-emerald-400 to-teal-600">
              <Users className="h-4 w-4 text-white" />
            </span>
            Utilisateurs
          </h1>
          <p className="mt-1 text-sm text-white/45">
            Comptes, rôles, premium offert et remboursements Apple.
          </p>
        </div>
        <button
          type="button"
          onClick={() => {
            void usersQuery.refetch();
            if (tab === "refunds") void refundsQuery.refetch();
            if (tab === "audit") void auditQuery.refetch();
          }}
          className="flex items-center gap-1.5 rounded-lg border border-white/10 px-3 py-2 text-xs font-bold text-white/60 transition hover:bg-white/[0.06] hover:text-white"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${usersQuery.isFetching ? "animate-spin" : ""}`} />
          Rafraîchir
        </button>
      </header>

      {stats && (
        <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <StatCard label="Comptes" value={stats.totalPlayers} />
          <StatCard label="Actifs 7 jours" value={stats.activeSevenDays} tone="emerald" />
          <StatCard label="Accès premium" value={stats.premiumCount} tone="amber" />
          <StatCard label="Bêta-testeurs" value={stats.roleCounts.beta ?? 0} tone="sky" />
        </div>
      )}

      <div className="mb-4 flex items-center gap-1 rounded-xl border border-white/10 bg-white/[0.03] p-1">
        {([
          ["users", "Comptes"],
          ["refunds", "Remboursements"],
          ["audit", "Journal"],
        ] as const).map(([key, label]) => (
          <button
            key={key}
            type="button"
            onClick={() => setTab(key)}
            className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
              tab === key ? "bg-emerald-500 text-white" : "text-white/50 hover:bg-white/[0.07] hover:text-white"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "users" && (
        <div className="grid gap-4 lg:grid-cols-[1.35fr_1fr]">
          <section className="rounded-2xl border border-white/10 bg-white/[0.02]">
            <div className="flex flex-wrap items-center gap-2 border-b border-white/10 p-3">
              <div className="flex min-w-[200px] flex-1 items-center gap-2 rounded-lg border border-white/10 bg-black/30 px-2.5">
                <Search className="h-3.5 w-3.5 shrink-0 text-white/35" />
                <input
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === "Enter") submitSearch();
                  }}
                  onBlur={submitSearch}
                  placeholder="Nom, e-mail, code ami…"
                  className="w-full bg-transparent py-2 text-sm text-white placeholder:text-white/25 focus:outline-none"
                />
              </div>
              <select
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value as AdminRole | "all")}
                className="rounded-lg border border-white/10 bg-black/30 px-2.5 py-2 text-xs font-semibold text-white/70 focus:outline-none"
              >
                <option value="all">Tous les rôles</option>
                {ADMIN_ROLES.map((role) => (
                  <option key={role} value={role}>
                    {ROLE_LABELS[role]}
                  </option>
                ))}
              </select>
              <select
                value={inactiveDays}
                onChange={(e) => setInactiveDays(Number(e.target.value))}
                className="rounded-lg border border-white/10 bg-black/30 px-2.5 py-2 text-xs font-semibold text-white/70 focus:outline-none"
              >
                {INACTIVE_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </div>

            {usersQuery.isLoading ? (
              <LoadingRow />
            ) : usersQuery.isError ? (
              <ErrorRow message={(usersQuery.error as Error).message} />
            ) : users.length === 0 ? (
              <EmptyRow
                title="Aucun compte"
                detail={
                  stats?.totalPlayers === 0
                    ? "Personne ne s'est encore connecté en ligne. Les comptes apparaissent au premier duel ou à la première connexion."
                    : "Aucun compte ne correspond à ces filtres."
                }
              />
            ) : (
              <ul className="max-h-[62vh] divide-y divide-white/5 overflow-y-auto">
                {users.map((user) => (
                  <li key={user.id}>
                    <button
                      type="button"
                      onClick={() => setSelectedId(user.id)}
                      className={`flex w-full items-center gap-3 px-3 py-2.5 text-left transition hover:bg-white/[0.04] ${
                        selectedId === user.id ? "bg-emerald-500/10" : ""
                      }`}
                    >
                      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-white/[0.06] text-base">
                        {user.emoji}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="flex items-center gap-2">
                          <span className="truncate text-sm font-bold">{user.name}</span>
                          <RoleBadge role={user.role} />
                          {user.purchasedPremium && (
                            <span className="rounded-md border border-emerald-400/30 bg-emerald-400/10 px-1.5 py-0.5 text-[10px] font-bold text-emerald-200">
                              Abonné
                            </span>
                          )}
                        </span>
                        <span className="mt-0.5 block truncate text-[11px] text-white/40">
                          {user.email ?? "e-mail non communiqué"} · {user.friendCode}
                        </span>
                      </span>
                      <span className="hidden shrink-0 text-right text-[11px] text-white/40 sm:block">
                        <span className="block font-semibold text-white/60">{user.duels} duels</span>
                        {relativeTime(user.lastSeenAt)}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {stats && users.length > 0 && (
              <p className="border-t border-white/10 px-3 py-2 text-[11px] text-white/35">
                {users.length} affiché{users.length > 1 ? "s" : ""} sur {stats.total} résultat
                {stats.total > 1 ? "s" : ""}
              </p>
            )}
          </section>

          <section className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
            {!selectedId ? (
              <div className="grid h-full min-h-[300px] place-items-center text-center text-sm text-white/35">
                Choisis un compte pour voir sa fiche.
              </div>
            ) : detailQuery.isLoading ? (
              <LoadingRow />
            ) : detailQuery.isError ? (
              <ErrorRow message={(detailQuery.error as Error).message} />
            ) : selected ? (
              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <span className="grid h-12 w-12 place-items-center rounded-2xl bg-white/[0.06] text-2xl">
                    {selected.user.emoji}
                  </span>
                  <div className="min-w-0 flex-1">
                    <h2 className="truncate text-lg font-extrabold">{selected.user.name}</h2>
                    <p className="truncate text-xs text-white/45">
                      {selected.user.email ?? "e-mail non communiqué"}
                    </p>
                    <CopyableId id={selected.user.id} />
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-2 text-center">
                  <MiniStat label="Duels" value={selected.user.duels} />
                  <MiniStat label="Victoires" value={selected.user.wins} />
                  <MiniStat label="Amis" value={selected.friends} />
                </div>

                <dl className="space-y-1.5 rounded-xl border border-white/10 bg-black/20 p-3 text-xs">
                  <Row label="Inscrit le" value={formatDate(selected.user.createdAt)} />
                  <Row label="Vu" value={relativeTime(selected.user.lastSeenAt)} />
                  <Row label="Code ami" value={selected.user.friendCode} />
                  <Row label="Points" value={String(selected.user.points)} />
                </dl>

                <div>
                  <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-white/40">Rôle</h3>
                  <div className="flex flex-wrap gap-1.5">
                    {ADMIN_ROLES.map((role) => {
                      const active = selected.user.role === role;
                      return (
                        <button
                          key={role}
                          type="button"
                          title={ROLE_HELP[role]}
                          disabled={roleMutation.isPending}
                          onClick={() => roleMutation.mutate({ userId: selected.user.id, role })}
                          className={`rounded-lg border px-2.5 py-1.5 text-[11px] font-bold transition disabled:opacity-50 ${
                            active ? ROLE_STYLES[role] : "border-white/10 text-white/45 hover:bg-white/[0.06]"
                          }`}
                        >
                          {active && <Check className="mr-1 inline h-3 w-3" />}
                          {ROLE_LABELS[role]}
                        </button>
                      );
                    })}
                  </div>
                  <p className="mt-1.5 text-[11px] text-white/35">{ROLE_HELP[selected.user.role]}</p>
                </div>

                <div className="rounded-xl border border-white/10 bg-black/20 p-3">
                  <h3 className="mb-2 text-xs font-bold uppercase tracking-wide text-white/40">Accès</h3>
                  <div className="mb-2.5 flex items-center justify-between text-xs">
                    <span className="text-white/55">Premium offert</span>
                    <button
                      type="button"
                      disabled={premiumMutation.isPending}
                      onClick={() =>
                        premiumMutation.mutate({
                          userId: selected.user.id,
                          grant: !selected.access.grantedPremium,
                        })
                      }
                      className={`flex items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-[11px] font-bold transition disabled:opacity-50 ${
                        selected.access.grantedPremium
                          ? "border-amber-400/30 bg-amber-400/10 text-amber-200 hover:bg-amber-400/20"
                          : "border-white/10 text-white/50 hover:bg-white/[0.06]"
                      }`}
                    >
                      <Gift className="h-3 w-3" />
                      {selected.access.grantedPremium ? "Offert — retirer" : "Offrir"}
                    </button>
                  </div>
                  <div className="flex items-center justify-between text-xs">
                    <span className="text-white/55">Abonnement acheté</span>
                    <span className="text-[11px] font-semibold text-white/40">
                      {selected.access.purchase
                        ? `${selected.access.purchase.status} · ${selected.access.purchase.productId ?? "produit inconnu"}`
                        : "aucun"}
                    </span>
                  </div>
                  <p className="mt-2 text-[11px] leading-relaxed text-white/30">
                    L'abonnement acheté vient d'Apple et ne peut pas être modifié ici.
                  </p>
                </div>

                {selected.refunds.length > 0 && (
                  <div className="rounded-xl border border-red-500/20 bg-red-500/[0.06] p-3">
                    <h3 className="mb-1.5 flex items-center gap-1.5 text-xs font-bold text-red-200">
                      <RotateCcw className="h-3.5 w-3.5" />
                      Remboursements Apple
                    </h3>
                    {selected.refunds.map((refund) => (
                      <p key={refund.eventId} className="text-[11px] text-white/50">
                        {formatDate(refund.refundedAt)} · {formatAmount(refund.amountCents, refund.currency)}
                      </p>
                    ))}
                  </div>
                )}

                {selected.audit.length > 0 && (
                  <div>
                    <h3 className="mb-1.5 text-xs font-bold uppercase tracking-wide text-white/40">
                      Historique admin
                    </h3>
                    <ul className="space-y-1">
                      {selected.audit.slice(0, 6).map((entry) => (
                        <li key={entry.id} className="text-[11px] text-white/45">
                          <span className="text-white/65">{auditLabel(entry.action)}</span> ·{" "}
                          {relativeTime(entry.at)} · {entry.actor}
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                <div className="flex flex-wrap gap-2 border-t border-white/10 pt-3">
                  <button
                    type="button"
                    disabled={exportMutation.isPending}
                    onClick={() => exportMutation.mutate(selected.user.id)}
                    className="flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-[11px] font-bold text-white/55 transition hover:bg-white/[0.06] hover:text-white disabled:opacity-50"
                  >
                    <Download className="h-3 w-3" />
                    Exporter (RGPD)
                  </button>
                  {confirmDelete === selected.user.id ? (
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        disabled={deleteMutation.isPending}
                        onClick={() => deleteMutation.mutate(selected.user.id)}
                        className="flex items-center gap-1.5 rounded-lg border border-red-500/40 bg-red-500/15 px-2.5 py-1.5 text-[11px] font-bold text-red-200 transition hover:bg-red-500/25 disabled:opacity-50"
                      >
                        {deleteMutation.isPending ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <AlertTriangle className="h-3 w-3" />
                        )}
                        Confirmer la suppression
                      </button>
                      <button
                        type="button"
                        onClick={() => setConfirmDelete(null)}
                        className="rounded-lg px-2 py-1.5 text-[11px] font-bold text-white/40 hover:text-white"
                      >
                        Annuler
                      </button>
                    </div>
                  ) : (
                    <button
                      type="button"
                      onClick={() => setConfirmDelete(selected.user.id)}
                      className="flex items-center gap-1.5 rounded-lg border border-white/10 px-2.5 py-1.5 text-[11px] font-bold text-white/45 transition hover:border-red-500/40 hover:bg-red-500/10 hover:text-red-300"
                    >
                      <Trash2 className="h-3 w-3" />
                      Supprimer le compte
                    </button>
                  )}
                </div>
                <p className="text-[11px] leading-relaxed text-white/25">
                  La progression d'apprentissage (leçons, séries, thèmes) reste sur l'appareil du joueur
                  et n'est pas visible ici.
                </p>
              </div>
            ) : null}
          </section>
        </div>
      )}

      {tab === "refunds" && (
        <section className="rounded-2xl border border-white/10 bg-white/[0.02]">
          <div className="border-b border-white/10 p-3">
            <p className="text-xs leading-relaxed text-white/45">
              Seul Apple accorde un remboursement, à la demande du client sur reportaproblem.apple.com.
              Cette liste est un registre : dès qu'un remboursement arrive, l'accès premium est coupé
              automatiquement.
            </p>
          </div>
          {refundsQuery.isLoading ? (
            <LoadingRow />
          ) : refundsQuery.isError ? (
            <ErrorRow message={(refundsQuery.error as Error).message} />
          ) : (refundsQuery.data?.length ?? 0) === 0 ? (
            <EmptyRow
              title="Aucun remboursement"
              detail="Rien à signaler. Cette page se remplira automatiquement quand Apple accordera un remboursement."
            />
          ) : (
            <ul className="divide-y divide-white/5">
              {refundsQuery.data?.map((refund) => (
                <li key={refund.eventId} className="flex items-center justify-between gap-3 px-3 py-2.5">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-bold">{refund.playerName ?? refund.userId}</p>
                    <p className="text-[11px] text-white/40">
                      {refund.productId ?? "produit inconnu"} · {refund.reason ?? "motif non précisé"}
                    </p>
                  </div>
                  <div className="shrink-0 text-right">
                    <p className="text-sm font-bold text-red-300">
                      −{formatAmount(refund.amountCents, refund.currency)}
                    </p>
                    <p className="text-[11px] text-white/35">{formatDate(refund.refundedAt)}</p>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {tab === "audit" && (
        <section className="rounded-2xl border border-white/10 bg-white/[0.02]">
          <div className="border-b border-white/10 p-3">
            <p className="text-xs text-white/45">
              Toute action du back-office sur un compte est tracée ici.
            </p>
          </div>
          {auditQuery.isLoading ? (
            <LoadingRow />
          ) : auditQuery.isError ? (
            <ErrorRow message={(auditQuery.error as Error).message} />
          ) : (auditQuery.data?.length ?? 0) === 0 ? (
            <EmptyRow title="Journal vide" detail="Aucune action n'a encore été effectuée sur un compte." />
          ) : (
            <ul className="divide-y divide-white/5">
              {auditQuery.data?.map((entry) => (
                <li key={entry.id} className="flex items-center justify-between gap-3 px-3 py-2">
                  <div className="min-w-0">
                    <p className="truncate text-xs font-bold text-white/75">{auditLabel(entry.action)}</p>
                    <p className="truncate text-[11px] text-white/40">{entry.detail ?? "—"}</p>
                  </div>
                  <p className="shrink-0 text-right text-[11px] text-white/35">
                    {entry.actor}
                    <span className="block">{relativeTime(entry.at)}</span>
                  </p>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </div>
  );
};

const StatCard = ({
  label,
  value,
  tone = "slate",
}: {
  label: string;
  value: number;
  tone?: "slate" | "emerald" | "amber" | "sky";
}) => {
  const tones: Record<string, string> = {
    slate: "text-white",
    emerald: "text-emerald-300",
    amber: "text-amber-300",
    sky: "text-sky-300",
  };
  return (
    <div className="rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2.5">
      <p className={`text-xl font-extrabold tabular-nums ${tones[tone]}`}>{value}</p>
      <p className="text-[11px] font-semibold uppercase tracking-wide text-white/35">{label}</p>
    </div>
  );
};

const MiniStat = ({ label, value }: { label: string; value: number }) => (
  <div className="rounded-xl border border-white/10 bg-black/20 py-2">
    <p className="text-base font-extrabold tabular-nums">{value}</p>
    <p className="text-[10px] uppercase tracking-wide text-white/35">{label}</p>
  </div>
);

const Row = ({ label, value }: { label: string; value: string }) => (
  <div className="flex items-center justify-between gap-3">
    <dt className="text-white/40">{label}</dt>
    <dd className="truncate font-semibold text-white/70">{value}</dd>
  </div>
);

const RoleBadge = ({ role }: { role: AdminRole }) => {
  if (role === "standard") return null;
  return (
    <span className={`shrink-0 rounded-md border px-1.5 py-0.5 text-[10px] font-bold ${ROLE_STYLES[role]}`}>
      {role === "banned" && <Ban className="mr-0.5 inline h-2.5 w-2.5" />}
      {ROLE_LABELS[role]}
    </span>
  );
};

const CopyableId = ({ id }: { id: string }) => {
  const [copied, setCopied] = useState<boolean>(false);
  return (
    <button
      type="button"
      onClick={() => {
        void navigator.clipboard.writeText(id);
        setCopied(true);
        window.setTimeout(() => setCopied(false), 1500);
      }}
      className="mt-1 flex items-center gap-1 text-[10px] font-mono text-white/25 transition hover:text-white/50"
    >
      {copied ? <Check className="h-2.5 w-2.5" /> : <Copy className="h-2.5 w-2.5" />}
      {id.slice(0, 22)}…
    </button>
  );
};

const LoadingRow = () => (
  <div className="grid place-items-center py-12 text-white/35">
    <Loader2 className="h-5 w-5 animate-spin" />
  </div>
);

const ErrorRow = ({ message }: { message: string }) => (
  <div className="grid place-items-center gap-1 px-4 py-12 text-center">
    <AlertTriangle className="h-5 w-5 text-red-400" />
    <p className="text-sm font-bold text-red-300">Impossible de charger</p>
    <p className="text-xs text-white/40">{message}</p>
  </div>
);

const EmptyRow = ({ title, detail }: { title: string; detail: string }) => (
  <div className="grid place-items-center gap-1 px-6 py-12 text-center">
    <p className="text-sm font-bold text-white/60">{title}</p>
    <p className="max-w-md text-xs leading-relaxed text-white/35">{detail}</p>
  </div>
);

export default AdminUsers;
