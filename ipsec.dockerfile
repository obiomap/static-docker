#!/usr/bin/env -S docker build --compress -t pvtmert/ipsec -f

FROM debian:9

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y \
	racoon iptables procps nano

ARG USER=vpn
ARG PASS=net
ARG GROUP=users
RUN useradd -MNro \
	-u "${UID:-999}" \
	-g "${GROUP}" \
	-s "/bin/sh" \
	-d "/home" \
	"${USER}"
RUN passwd -du "${USER}"
RUN echo "${USER}:${PASS}" | chpasswd | tee /password.txt

WORKDIR /etc/racoon
RUN echo "*\trandompsk" | tee -a psk.txt

# see: https://www.daemon-systems.org/man/racoon.conf.5.html
RUN ( \
	echo "remote anonymous {"          ; \
	echo "  exchange_mode"             ; \
	echo "    main, aggressive;"       ; \
	echo "  generate_policy unique;"   ; \
	echo "  nat_traversal on;"         ; \
	echo "  passive on;"               ; \
	echo "  proposal {"                ; \
	echo "    authentication_method"   ; \
	echo "      xauth_psk_server;"     ; \
	echo "    encryption_algorithm"    ; \
	echo "      aes;"                  ; \
	echo "    hash_algorithm md5;"     ; \
	echo "    # md5, sha1, sha256"     ; \
	echo "    dh_group modp2048;"      ; \
	echo "    # modp1024, modp4096"    ; \
	echo "	}"                         ; \
	echo "}"                           ; \
	echo "sainfo anonymous {"          ; \
	echo "  lifetime time 6 hour;"     ; \
	echo "  compression_algorithm"     ; \
	echo "    deflate;"                ; \
	echo "  encryption_algorithm aes;" ; \
	echo "  authentication_algorithm"  ; \
	echo "    hmac_md5,"               ; \
	echo "    hmac_sha1,"              ; \
	: echo "    hmac_sha256,"          ; \
	echo "    non_auth;"               ; \
	echo "}"                           ; \
	echo "mode_cfg {"                  ; \
	echo "  auth_source pam;"          ; \
	echo "  save_passwd on;"           ; \
	echo "  banner \"/etc/motd\";"     ; \
	echo "  pool_size 64;"             ; \
	echo "  dns4 0.0.0.0;"             ; \
	echo "  dns4 1.1.1.1;"             ; \
	echo "  dns4 8.8.8.8;"             ; \
	echo "  #dns4 208.67.222.222;"     ; \
	echo "  network4 192.168.99.11;"   ; \
	echo "  #netmask4 255.255.255.0;"  ; \
	echo "}"                           ; \
	echo "complex_bundle on;"          ; \
) | tee -a racoon.conf

EXPOSE 500/udp 4500/udp
RUN mkdir --mode=0777 -p /var/run/racoon
CMD ( \
	iptables -v -t nat -A POSTROUTING -j MASQUERADE; \
	sysctl -w net.ipv4.ip_forward=1; \
	cat -n /password.txt; \
	tail -1 psk.txt; \
	racoon -4Fdv || ( \
		export CODE=$?; \
		cat -n racoon.conf; \
		exit $((CODE)); \
	); \
)

