<?xml version="1.0"?>
<opnsense>
  <theme>opnsense</theme>
  <sysctl/>
  <system>
    <optimization>normal</optimization>
    <hostname>opnsense</hostname>
    <domain>internal</domain>
    <dnsallowoverride>1</dnsallowoverride>
    <dnsallowoverride_exclude/>
    <group>
      <name>admins</name>
      <description>System Administrators</description>
      <scope>system</scope>
      <gid>1999</gid>
      <member>0</member>
      <priv>page-all</priv>
    </group>
    <user>
      <name>root</name>
      <descr>System Administrator</descr>
      <scope>system</scope>
      <groupname>admins</groupname>
      <!-- default password is opnsense -->
      <password>$2y$10$YRVoF4SgskIsrXOvOQjGieB9XqHPRra9R7d80B3BZdbY/j21TwBfS</password>
      <uid>0</uid>
    </user>
    <user>
      <uid>1001</uid>
      <name>opentofu</name>
      <descr>OpenTofu Automation Account</descr>
      <scope>user</scope>
      <groupname>admins</groupname>
      <password>*</password> 
      <language>en_US</language>
      <shell>/sbin/nologin</shell>
      <!--
        API key format reverse-engineered from OPNsense 26.1.2 config.xml export.
        No official documentation exists for this format.
        Format: <plaintext_key>|<sha512_hash_of_secret>
        Hash is SHA-512 crypt ($6$) with empty salt
        Note: verify this format still holds when upgrading OPNsense versions.
      -->
      <apikeys>${opnsense_api_key}|__API_SECRET_HASHED__</apikeys>
    </user>
    <timezone>Etc/UTC</timezone>
    <timeservers>0.opnsense.pool.ntp.org 1.opnsense.pool.ntp.org 2.opnsense.pool.ntp.org 3.opnsense.pool.ntp.org</timeservers>
    <webgui>
      <protocol>https</protocol>
    </webgui>
    <disablenatreflection>yes</disablenatreflection>
    <usevirtualterminal>1</usevirtualterminal>
    <disableconsolemenu/>
    <ipv6allow>0</ipv6allow>
    <powerd_ac_mode>hadp</powerd_ac_mode>
    <powerd_battery_mode>hadp</powerd_battery_mode>
    <powerd_normal_mode>hadp</powerd_normal_mode>
    <bogons>
      <interval>monthly</interval>
    </bogons>
    <pf_share_forward>1</pf_share_forward>
    <lb_use_sticky>1</lb_use_sticky>
    <ssh>
      <group>admins</group>
    </ssh>
    <rrdbackup>-1</rrdbackup>
    <netflowbackup>-1</netflowbackup>
  </system>
  <interfaces>
    <wan>
      <if>vtnet0</if>
      <enable>1</enable>
      <descr>WAN_FROM_ROUTER</descr>
      <ipaddr>dhcp</ipaddr>
      <blockpriv>0</blockpriv> 
      <blockbogons>0</blockbogons>
    </wan>
    <lan>
      <if>vtnet1</if>
      <enable>1</enable>
      <descr>MANAGEMENT_LAN</descr>
      <ipaddr>10.0.0.1</ipaddr>
      <subnet>24</subnet>
    </lan>
    <opt1>
      <if>vtnet2</if>
      <enable>1</enable>
      <descr>DMZ_SERVERS</descr>
      <ipaddr>10.0.10.1</ipaddr>
      <subnet>24</subnet>
    </opt1>
    <opt2>
      <if>vtnet3</if>
      <enable>1</enable>
      <descr>PC_ISOLATED</descr>
      <ipaddr>10.0.20.1</ipaddr>
      <subnet>24</subnet>
    </opt2>
    <!-- Wireguard VPN Tunnel interface -->
    %{~ if wg_privkey != "" ~}
    <wireguard>
      <internal_dynamic>1</internal_dynamic>
      <if>wireguard</if>
      <descr>WireGuard (Group)</descr>
      <enable>1</enable>
      <virtual>1</virtual>
      <type>group</type>
      <networks/>
    </wireguard>
    <opt3>
      <if>wg0</if>
      <descr>VPN_TUNNEL</descr>
    </opt3>
    %{~ endif ~}
  </interfaces>
  <unbound>
    <enable>1</enable>
  </unbound>
  <nat>
    <outbound>
      <mode>automatic</mode>
    </outbound>
  </nat>
  <filter>
    <rule>
      <type>pass</type>
      <ipprotocol>inet</ipprotocol>
      <descr>Default allow LAN to any rule</descr>
      <interface>lan</interface>
      <source>
        <network>lan</network>
      </source>
      <destination>
        <any/>
      </destination>
    </rule>

    %{~ if wg_privkey != "" ~}
    <rule>
      <type>pass</type>
      <interface>wan</interface>
      <descr>Allow WG Handshake</descr>
      <protocol>udp</protocol>
      <source>
        <any/>
      </source>
      <destination>
        <any/>
        <port>51820</port>
      </destination>
    </rule>
    
    <rule>
      <type>pass</type>
      <interface>wireguard</interface>
      <descr>Allow VPN to API</descr>
      <protocol>tcp</protocol>
      <source>
        <address>10.1.0.0/24</address>
      </source>
      <destination>
        <address>10.0.0.1/32</address>
        <port>443</port>
      </destination>
    </rule>

    <rule>
      <type>pass</type>
      <interface>wireguard</interface>
      <descr>Allow VPN to DNS</descr>
      <protocol>tcp/udp</protocol>
      <source>
        <address>10.1.0.0/24</address>
      </source>
      <destination>
        <address>10.0.0.1/32</address>
        <port>53</port>
      </destination>
    </rule>
    %{~ endif ~}
  </filter>
  <rrd>
    <enable/>
  </rrd>
  <ntpd>
    <prefer>0.opnsense.pool.ntp.org</prefer>
  </ntpd>
  %{~ if wg_privkey != "" ~}
  <OPNsense>
    <wireguard>
      <general version="0.0.1">
        <enabled>1</enabled>
      </general>
      <client version="1.0.0">
        <clients>
          <client uuid="70a1c086-a63d-4976-911b-4d024750aa4c">
            <enabled>1</enabled>
            <name>PCAccess</name>
            <pubkey>${wg_client_pubkey}</pubkey>
            <tunneladdress>10.1.0.1/24</tunneladdress>
            <keepalive>25</keepalive>
            <psk/>
            <serveraddress/>
            <serverport/>
          </client>
        </clients>
      </client>
      <server version="1.0.1">
        <servers>
          <server uuid="${uuidv4()}">
            <enabled>1</enabled>
            <name>ManagementVPN</name>
            <instance>0</instance>
            <port>51820</port>
            <tunneladdress>10.1.0.1/24</tunneladdress>
            <disableroutes>0</disableroutes>
            <privkey>${wg_privkey}</privkey>
            <pubkey>${wg_pubkey}</pubkey>
            <peers>70a1c086-a63d-4976-911b-4d024750aa4c</peers>
            <gateway/>
            <carp_depend_on/>
            <debug>0</debug>
            <endpoint/>
            <peer_dns/>
            <mtu/>
            <dns/>
          </server>
        </servers>
      </server>
    </wireguard>
  </OPNsense>
  %{~ endif ~}
</opnsense>
