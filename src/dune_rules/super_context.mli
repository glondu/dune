(** A context augmented with the ability to add rules that respect the env
    stanza.

    Avoid adding new code here. This module doesn't have a specific purpose and
    is essentially a grab of random stuff. It will eventually be eliminated. *)

open Import

type t

val all : t Context_name.Map.t Memo.Lazy.t

(** In order to break circular dependencies within [all], some initialization is
    deferred *)
val all_init_deferred : unit -> unit Memo.t

(** Find a super context by name. *)
val find : Context_name.t -> t option Memo.t

val to_dyn : t -> Dyn.t
val context : t -> Context.t

(** Context env with additional variables computed from packages *)
val context_env : t -> Env.t

(** Compute the ocaml flags based on the directory environment and a buildable
    stanza *)
val ocaml_flags : t -> dir:Path.Build.t -> Ocaml_flags.Spec.t -> Ocaml_flags.t Memo.t

val js_of_ocaml_runtest_alias : t -> dir:Path.Build.t -> Alias.Name.t Memo.t

val default_foreign_flags
  :  t
  -> dir:Path.Build.t
  -> language:Foreign_language.t
  -> string list Action_builder.t

val foreign_flags
  :  t
  -> dir:Path.Build.t
  -> expander:Expander.t
  -> flags:Ordered_set_lang.Unexpanded.t
  -> language:Foreign_language.t
  -> string list Action_builder.t

val link_flags : t -> dir:Path.Build.t -> Link_flags.Spec.t -> Link_flags.t Memo.t

(** Binaries that are symlinked in the associated .bin directory of [dir]. This
    associated directory is [Path.relative dir ".bin"] *)
val local_binaries : t -> dir:Path.Build.t -> File_binding.Expanded.t list Memo.t

val env_node : t -> dir:Path.Build.t -> Env_node.t Memo.t
val bin_annot : t -> dir:Path.Build.t -> bool Memo.t

(** Dump a directory environment in a readable form *)
val dump_env : t -> dir:Path.Build.t -> Dune_lang.t list Action_builder.t

val add_rule
  :  t
  -> ?mode:Rule.Mode.t
  -> ?loc:Loc.t
  -> dir:Path.Build.t
  -> Action.Full.t Action_builder.With_targets.t
  -> unit Memo.t

val add_rule_get_targets
  :  t
  -> ?mode:Rule.Mode.t
  -> ?loc:Loc.t
  -> dir:Path.Build.t
  -> Action.Full.t Action_builder.With_targets.t
  -> Targets.Validated.t Memo.t

val add_rules
  :  t
  -> ?loc:Loc.t
  -> dir:Path.Build.t
  -> Action.Full.t Action_builder.With_targets.t list
  -> unit Memo.t

val add_alias_action
  :  t
  -> Alias.t
  -> dir:Path.Build.t
  -> loc:Loc.t
  -> Action.Full.t Action_builder.t
  -> unit Memo.t

(** [resolve_program t ?hint name] resolves a program. [name] is looked up in
    the workspace, if it is not found in the tree is is looked up in the PATH.
    If it is not found at all, the resulting [Action.Prog.t] will either return
    the resolved path or a record with details about the error and possibly a
    hint.

    [hint] should tell the user what to install when the program is not found. *)
val resolve_program
  :  t
  -> dir:Path.Build.t
  -> ?hint:string
  -> loc:Loc.t option
  -> string
  -> Action.Prog.t Memo.t

val expander : t -> dir:Path.Build.t -> Expander.t Memo.t

module As_memo_key : sig
  include Memo.Input with type t = t
  module And_package : Memo.Input with type t = t * Package.t
end
