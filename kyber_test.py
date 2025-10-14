import oqs, time

def roundtrip(kem_name="Kyber512"):
    with oqs.KeyEncapsulation(kem_name) as client:
        with oqs.KeyEncapsulation(kem_name) as server:
            pk = server.generate_keypair()
            ct, ss_client = client.encap_secret(pk)
            ss_server = server.decap_secret(ct)
            assert ss_client == ss_server
            return len(pk), len(ct), len(ss_client)

def bench(kem_name="Kyber512", iters=200):
    with oqs.KeyEncapsulation(kem_name) as kem:
        t0 = time.time()
        for _ in range(iters):
            kem.generate_keypair()
        t1 = time.time()
    return iters / (t1 - t0)

if __name__ == "__main__":
    print("Kyber KEMs:", [k for k in oqs.get_enabled_kem_mechanisms() if "Kyber" in k])
    pk_len, ct_len, ss_len = roundtrip("Kyber512")
    print(f"Kyber512 OK | pk={pk_len} bytes, ct={ct_len} bytes, ss={ss_len} bytes")
    print(f"~{bench('Kyber512'):.1f} keygens/sec (rough, single-thread)")

