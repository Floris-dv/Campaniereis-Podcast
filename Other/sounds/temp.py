for f in ['audio0.wav']:#, 'audio1.wav', 'audio2.wav', 'audio3.wav', 'audio4.wav']:
    with open(f, 'rb') as file:
        print(list(map(lambda x: '0x' + x, file.read().hex(',', 4).split(','))))
    print('FINISHED')