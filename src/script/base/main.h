#include <api.h>

namespace scm {
template <> struct convertible<mce::UUID> : foreign_object_is_convertible<mce::UUID> {};
template <> struct convertible<ServerPlayer *> : foreign_object_is_convertible<ServerPlayer *> {};
template <> struct convertible<ItemActor *> : foreign_object_is_convertible<ItemActor *> {};
template <> struct convertible<Actor *> : foreign_object_is_convertible<Actor *> {
  static SCM to_scm(Actor *act) {
    if (auto player = dynamic_cast<ServerPlayer *>(act); player) { return foreign_object_is_convertible<ServerPlayer *>::to_scm(player); }
    if (auto itemActor = dynamic_cast<ItemActor *>(act); itemActor) { return foreign_object_is_convertible<ItemActor *>::to_scm(itemActor); }
    return foreign_object_is_convertible<Actor *>::to_scm(act);
  }
  static Actor *from_scm(SCM act) {
    if (SCM_IS_A_P(act, foreign_type_convertible<ServerPlayer *>::type())) {
      return (Actor *)foreign_object_is_convertible<ServerPlayer *>::from_scm(act);
    }
    if (SCM_IS_A_P(act, foreign_type_convertible<ItemActor *>::type())) { return (Actor *)foreign_object_is_convertible<ItemActor *>::from_scm(act); }
    return foreign_object_is_convertible<Actor *>::from_scm(act);
  }
};
template <> struct convertible<ItemInstance *> : foreign_object_is_convertible<ItemInstance *> {};
} // namespace scm