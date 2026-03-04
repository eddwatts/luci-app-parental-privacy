include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-parental-privacy
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Edward Watts

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-parental-privacy
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Parental Privacy Wizard
  DEPENDS:=+luci-base +tc-full +kmod-sched-core +nftables
  PKGARCH:=all
endef

define Package/luci-app-parental-privacy/description
  A private, isolated Kids WiFi network with hardware toggle and DNS hijacking.
endef

define Build/Compile
endef

define Package/luci-app-parental-privacy/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/parental_privacy
	$(INSTALL_DIR) $(1)/usr/share/parental-privacy
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/hotplug.d/button

	$(INSTALL_BIN) ./files/bandwidth.sh $(1)/usr/share/parental-privacy/
	$(INSTALL_BIN) ./files/block-doh.sh $(1)/usr/share/parental-privacy/
	$(INSTALL_BIN) ./files/99-parental-privacy $(1)/etc/uci-defaults/
	$(INSTALL_BIN) ./files/30-kids-wifi $(1)/etc/hotplug.d/button/

	$(INSTALL_DATA) ./files/parental_privacy.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DATA) ./files/kids_network.htm $(1)/usr/lib/lua/luci/view/parental_privacy/
	$(INSTALL_DATA) ./files/wizard.htm $(1)/usr/lib/lua/luci/view/parental_privacy/
	$(INSTALL_DATA) ./files/luci-app-parental-privacy.json $(1)/usr/share/rpcd/acl.d/
endef

$(eval $(call BuildPackage,luci-app-parental-privacy))
